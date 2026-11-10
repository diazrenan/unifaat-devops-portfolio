#!/bin/bash

# Blue/Green Deployment Script
# Automatiza o processo de deploy de uma cor para outra

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="$(dirname "$0")/../terraform"
HEALTH_CHECK_TIMEOUT=300  # 5 minutes
HEALTH_CHECK_INTERVAL=10  # 10 seconds

# Functions
print_header() {
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Verificando pré-requisitos"

    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform não encontrado. Instale antes de continuar."
        exit 1
    fi
    print_success "Terraform: $(terraform version -json | jq -r '.terraform_version')"

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI não encontrado. Instale antes de continuar."
        exit 1
    fi
    print_success "AWS CLI: $(aws --version | awk '{print $1}')"

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials não configurados. Execute 'aws configure'"
        exit 1
    fi
    print_success "AWS credentials: OK"
}

# Get outputs from Terraform
get_terraform_outputs() {
    print_header "Obtendo outputs do Terraform"

    cd "$TERRAFORM_DIR"
    
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    BLUE_TG=$(terraform output -raw blue_tg_arn 2>/dev/null || echo "")
    GREEN_TG=$(terraform output -raw green_tg_arn 2>/dev/null || echo "")
    LISTENER_ARN=$(terraform output -raw listener_arn 2>/dev/null || echo "")

    if [ -z "$ALB_DNS" ] || [ -z "$BLUE_TG" ] || [ -z "$GREEN_TG" ] || [ -z "$LISTENER_ARN" ]; then
        print_error "Não foi possível obter outputs do Terraform"
        print_info "Execute 'terraform apply' no diretório terraform/ primeiro"
        exit 1
    fi

    print_success "ALB DNS: $ALB_DNS"
    print_success "Blue TG: $(echo $BLUE_TG | cut -d'/' -f3)"
    print_success "Green TG: $(echo $GREEN_TG | cut -d'/' -f3)"
    print_success "Listener ARN: $(echo $LISTENER_ARN | cut -d':' -f6)"
}

# Get current active color
get_active_color() {
    print_info "Identificando ambiente ativo..."
    
    CURRENT_TG=$(aws elbv2 describe-listeners \
        --listener-arns "$LISTENER_ARN" \
        --query 'Listeners[0].DefaultActions[0].TargetGroupArn' \
        --output text 2>/dev/null)

    if [[ "$CURRENT_TG" == *"blue"* ]]; then
        ACTIVE_COLOR="blue"
        STANDBY_COLOR="green"
        STANDBY_TG="$GREEN_TG"
    else
        ACTIVE_COLOR="green"
        STANDBY_COLOR="blue"
        STANDBY_TG="$BLUE_TG"
    fi

    print_success "Ambiente ativo: $ACTIVE_COLOR"
    print_success "Ambiente standby: $STANDBY_COLOR"
}

# Check health of target group
check_target_health() {
    local tg_arn=$1
    local color=$2
    
    print_info "Verificando health dos targets no $color..."

    local health_output=$(aws elbv2 describe-target-health \
        --target-group-arn "$tg_arn" \
        --output json)

    local healthy_count=$(echo "$health_output" | jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State=="healthy")] | length')
    local total_count=$(echo "$health_output" | jq '.TargetHealthDescriptions | length')

    if [ "$healthy_count" -gt 0 ]; then
        print_success "Health check ($color): $healthy_count/$total_count saudáveis"
        return 0
    else
        print_error "Health check ($color): 0/$total_count saudáveis"
        return 1
    fi
}

# Wait for health checks to pass
wait_for_health_checks() {
    local tg_arn=$1
    local color=$2
    local timeout=$3
    local start_time=$(date +%s)

    print_header "Aguardando health checks do ambiente $color"

    while true; do
        if check_target_health "$tg_arn" "$color"; then
            return 0
        fi

        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [ $elapsed -ge $timeout ]; then
            print_error "Health checks não passaram dentro de $timeout segundos"
            return 1
        fi

        print_info "Tentando novamente em $HEALTH_CHECK_INTERVAL segundos..."
        sleep $HEALTH_CHECK_INTERVAL
    done
}

# Perform health check via HTTP
http_health_check() {
    print_header "Fazendo health check HTTP no ALB"

    local start_time=$(date +%s)

    while true; do
        if curl -s -f "http://$ALB_DNS/" > /dev/null 2>&1; then
            print_success "ALB respondendo corretamente"
            return 0
        fi

        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [ $elapsed -ge $HEALTH_CHECK_TIMEOUT ]; then
            print_error "ALB não respondeu dentro de $HEALTH_CHECK_TIMEOUT segundos"
            return 1
        fi

        echo -n "."
        sleep 5
    done
}

# Switch traffic
switch_traffic() {
    print_header "Redirecionando tráfego para $STANDBY_COLOR"

    print_info "Modificando listener..."
    aws elbv2 modify-listener \
        --listener-arn "$LISTENER_ARN" \
        --default-actions Type=forward,TargetGroupArn="$STANDBY_TG" \
        > /dev/null

    sleep 5  # Wait for propagation

    if http_health_check; then
        print_success "Tráfego redirecionado com sucesso!"
        return 0
    else
        print_error "Health check falhou após redirect"
        print_warning "Revertendo para $ACTIVE_COLOR..."
        
        if [[ "$ACTIVE_COLOR" == "blue" ]]; then
            aws elbv2 modify-listener \
                --listener-arn "$LISTENER_ARN" \
                --default-actions Type=forward,TargetGroupArn="$BLUE_TG" \
                > /dev/null
        else
            aws elbv2 modify-listener \
                --listener-arn "$LISTENER_ARN" \
                --default-actions Type=forward,TargetGroupArn="$GREEN_TG" \
                > /dev/null
        fi
        
        print_error "Rollback concluído"
        return 1
    fi
}

# Display status
display_status() {
    print_header "Status Atual"
    
    local blue_health=$(aws elbv2 describe-target-health \
        --target-group-arn "$BLUE_TG" \
        --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
        --output text)

    local green_health=$(aws elbv2 describe-target-health \
        --target-group-arn "$GREEN_TG" \
        --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
        --output text)

    echo -e "ALB DNS: ${BLUE}$ALB_DNS${NC}"
    echo -e "Ambiente ativo: ${GREEN}$ACTIVE_COLOR${NC}"
    echo -e "Ambiente standby: ${YELLOW}$STANDBY_COLOR${NC}"
    echo -e "Blue targets saudáveis: ${GREEN}$blue_health${NC}"
    echo -e "Green targets saudáveis: ${GREEN}$green_health${NC}"
}

# Main deployment process
deploy() {
    print_header "Blue/Green Deployment Process"

    check_prerequisites
    get_terraform_outputs
    get_active_color

    print_info "Você está prestes a fazer deploy para: $STANDBY_COLOR"
    read -p "Deseja continuar? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        print_warning "Deploy cancelado"
        exit 0
    fi

    # Wait for health checks on standby environment
    if ! wait_for_health_checks "$STANDBY_TG" "$STANDBY_COLOR" "$HEALTH_CHECK_TIMEOUT"; then
        print_error "Não foi possível prosseguir - targets $STANDBY_COLOR não estão saudáveis"
        exit 1
    fi

    # Switch traffic
    if ! switch_traffic; then
        print_error "Falha ao redirecionar tráfego"
        exit 1
    fi

    # Display final status
    display_status

    print_success "Deploy concluído com sucesso!"
    print_info "Novo ambiente ativo: $STANDBY_COLOR"
}

# Show usage
usage() {
    cat << EOF
Uso: $0 [COMMAND]

Commands:
    deploy      Executar deploy de Blue/Green (padrão)
    status      Mostrar status atual
    rollback    Fazer rollback para ambiente anterior
    help        Mostrar esta mensagem

Exemplos:
    $0 deploy
    $0 status
    $0 rollback

EOF
}

# Main
case "${1:-deploy}" in
    deploy)
        deploy
        ;;
    status)
        check_prerequisites
        get_terraform_outputs
        get_active_color
        display_status
        ;;
    rollback)
        check_prerequisites
        get_terraform_outputs
        get_active_color
        print_header "Fazendo rollback para $ACTIVE_COLOR"
        switch_traffic
        ;;
    help)
        usage
        ;;
    *)
        echo "Comando desconhecido: $1"
        usage
        exit 1
        ;;
esac
