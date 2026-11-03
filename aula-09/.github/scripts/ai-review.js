#!/usr/bin/env node
// =============================================================================
// ai-review.js — Motor de análise estática de código para PRs
// TechNova API | Aula 09 — AI Review
//
// Uso:
//   node ai-review.js <diff_file>
//
// Saída:
//   - STDOUT: JSON com findings (consumido pelo workflow)
//   - Exit 1: se houver findings CRITICAL
//   - Exit 0: se não houver CRITICAL (apenas WARNING/INFO ou nada)
// =============================================================================

'use strict';

const fs   = require('fs');
const path = require('path');

// ─── Constantes ───────────────────────────────────────────────────────────────

const SEVERITY = {
  CRITICAL : 'CRITICAL',
  WARNING  : 'WARNING',
  INFO     : 'INFO',
};

// ─── Regras de análise ────────────────────────────────────────────────────────
// Cada regra define:
//   id          — identificador único
//   severity    — CRITICAL | WARNING | INFO
//   description — texto humano do problema
//   suggestion  — como corrigir
//   pattern     — RegExp testada em cada linha adicionada (+)
//   fileFilter  — RegExp opcional: só aplica em arquivos que casem

const RULES = [
  // ── CRITICAL ──────────────────────────────────────────────────────────────

  {
    id          : 'HARDCODED_SECRET',
    severity    : SEVERITY.CRITICAL,
    description : 'Possível secret hardcoded detectado',
    suggestion  : 'Use variáveis de ambiente (process.env) ou um secret manager (AWS Secrets Manager, Vault).',
    pattern     : /(?:password|passwd|secret|api[_-]?key|apikey|auth[_-]?token|access[_-]?token|private[_-]?key)\s*[:=]\s*['"`][^'"`\s]{4,}/i,
  },
  {
    id          : 'AWS_ACCESS_KEY',
    severity    : SEVERITY.CRITICAL,
    description : 'AWS Access Key ID hardcoded detectado',
    suggestion  : 'Nunca comite credenciais AWS. Use IAM roles ou variáveis de ambiente.',
    pattern     : /AKIA[0-9A-Z]{16}/,
  },
  {
    id          : 'AWS_SECRET_KEY',
    severity    : SEVERITY.CRITICAL,
    description : 'Possível AWS Secret Access Key hardcoded',
    suggestion  : 'Nunca comite credenciais AWS. Use IAM roles ou variáveis de ambiente.',
    pattern     : /(?:aws[_-]?secret|secret[_-]?access[_-]?key)\s*[:=]\s*['"`][A-Za-z0-9/+=]{20,}/i,
  },
  {
    id          : 'SQL_INJECTION',
    severity    : SEVERITY.CRITICAL,
    description : 'Possível SQL injection: query montada com concatenação de string',
    suggestion  : 'Use prepared statements / queries parametrizadas (ex: knex, pg parameterized queries).',
    pattern     : /(?:SELECT|INSERT|UPDATE|DELETE|DROP|UNION).*['"`]\s*\+\s*(?:req\.|params\.|body\.|query\.|user\.|input)/i,
  },
  {
    id          : 'SQL_INJECTION_TEMPLATE',
    severity    : SEVERITY.CRITICAL,
    description : 'Possível SQL injection: query montada com template literal + variável de request',
    suggestion  : 'Use prepared statements / queries parametrizadas.',
    pattern     : /`(?:SELECT|INSERT|UPDATE|DELETE|DROP|UNION)[^`]*\$\{(?:req|params|body|query|user|input)/i,
  },
  {
    id          : 'EVAL_USAGE',
    severity    : SEVERITY.CRITICAL,
    description : 'Uso de eval() detectado — risco de execução de código arbitrário',
    suggestion  : 'Evite eval(). Prefira JSON.parse() para dados ou refatore a lógica.',
    pattern     : /\beval\s*\(/,
  },
  {
    id          : 'EVAL_FUNCTION_CONSTRUCTOR',
    severity    : SEVERITY.CRITICAL,
    description : 'Uso de new Function() detectado — equivalente a eval()',
    suggestion  : 'Evite new Function(). Refatore a lógica sem execução dinâmica de código.',
    pattern     : /new\s+Function\s*\(/,
  },
  {
    id          : 'EXEC_SHELL_INJECTION',
    severity    : SEVERITY.CRITICAL,
    description : 'Possível injeção de shell: exec/execSync com concatenação de input externo',
    suggestion  : 'Use execFile() com array de argumentos, nunca concatene input do usuário em comandos shell.',
    pattern     : /(?:exec|execSync|spawn)\s*\([^)]*(?:req\.|params\.|body\.|query\.|user\.|input)/i,
  },

  // ── WARNING ───────────────────────────────────────────────────────────────

  {
    id          : 'CONSOLE_LOG',
    severity    : SEVERITY.WARNING,
    description : 'console.log() em código de produção',
    suggestion  : 'Use um logger estruturado (ex: winston, pino) que respeite níveis e não vaze dados em produção.',
    pattern     : /\bconsole\.log\s*\(/,
    fileFilter  : /\.(ts|js)$/,
  },
  {
    id          : 'EMPTY_CATCH',
    severity    : SEVERITY.WARNING,
    description : 'Bloco catch vazio — erros sendo silenciados',
    suggestion  : 'Sempre trate ou logue o erro no catch. Silenciar erros dificulta debugging.',
    pattern     : /catch\s*\([^)]*\)\s*\{\s*\}/,
  },
  {
    id          : 'TODO_FIXME',
    severity    : SEVERITY.WARNING,
    description : 'TODO/FIXME encontrado no código adicionado',
    suggestion  : 'Resolva o TODO antes de mergear ou crie uma issue para rastreamento.',
    pattern     : /\b(?:TODO|FIXME|HACK|XXX)\b/,
  },
  {
    id          : 'DEBUGGER_STATEMENT',
    severity    : SEVERITY.WARNING,
    description : 'Instrução debugger encontrada',
    suggestion  : 'Remova o debugger antes de mergear.',
    pattern     : /\bdebugger\b/,
  },
  {
    id          : 'WEAK_RANDOM',
    severity    : SEVERITY.WARNING,
    description : 'Math.random() usado para geração de valores (potencialmente segurança)',
    suggestion  : 'Para tokens, IDs sensíveis ou criptografia, use crypto.randomBytes() ou crypto.randomUUID().',
    pattern     : /\bMath\.random\s*\(/,
  },

  // ── INFO ──────────────────────────────────────────────────────────────────

  {
    id          : 'ANY_TYPE',
    severity    : SEVERITY.INFO,
    description : 'Uso de tipo "any" em TypeScript',
    suggestion  : 'Prefira tipos explícitos ou "unknown" com type narrowing para manter a segurança de tipos.',
    pattern     : /:\s*any\b/,
    fileFilter  : /\.ts$/,
  },
  {
    id          : 'CONSOLE_ERROR_WARN',
    severity    : SEVERITY.INFO,
    description : 'console.error/console.warn em código de produção',
    suggestion  : 'Considere substituir por um logger estruturado.',
    pattern     : /\bconsole\.(error|warn)\s*\(/,
    fileFilter  : /\.(ts|js)$/,
  },
  {
    id          : 'HARDCODED_URL',
    severity    : SEVERITY.INFO,
    description : 'URL hardcoded no código',
    suggestion  : 'Prefira variáveis de ambiente para URLs de serviços externos.',
    pattern     : /https?:\/\/(?!localhost|127\.0\.0\.1)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/,
  },
];

// ─── Parser de diff ───────────────────────────────────────────────────────────

/**
 * Parseia um unified diff e retorna uma lista de hunks com:
 *   { file, lineNumber, content }
 * Apenas linhas adicionadas (+) são retornadas (ignora contexto e remoções).
 */
function parseDiff(diffText) {
  const lines   = diffText.split('\n');
  const hunks   = [];
  let currentFile = null;
  let currentLine = 0;

  for (const raw of lines) {
    // Novo arquivo no diff
    if (raw.startsWith('+++ b/')) {
      currentFile = raw.slice(6).trim();
      currentLine = 0;
      continue;
    }
    if (raw.startsWith('---') || raw.startsWith('diff ') || raw.startsWith('index ')) {
      continue;
    }

    // Cabeçalho de hunk: @@ -L,S +L,S @@
    const hunkMatch = raw.match(/^@@\s+-\d+(?:,\d+)?\s+\+(\d+)(?:,\d+)?\s+@@/);
    if (hunkMatch) {
      currentLine = parseInt(hunkMatch[1], 10) - 1;
      continue;
    }

    if (!currentFile) continue;

    if (raw.startsWith('+')) {
      // Linha adicionada (ignora a linha "+++")
      currentLine++;
      hunks.push({
        file       : currentFile,
        lineNumber : currentLine,
        content    : raw.slice(1), // Remove o '+' inicial
      });
    } else if (!raw.startsWith('-')) {
      // Linha de contexto (nem + nem -)
      currentLine++;
    }
  }

  return hunks;
}

// ─── Analisador ───────────────────────────────────────────────────────────────

/**
 * Analisa os hunks e retorna findings.
 */
function analyze(hunks) {
  const findings = [];

  for (const hunk of hunks) {
    for (const rule of RULES) {
      // Aplica fileFilter se definido
      if (rule.fileFilter && !rule.fileFilter.test(hunk.file)) {
        continue;
      }

      if (rule.pattern.test(hunk.content)) {
        // Trunca a linha para não vazar dados sensíveis no comentário
        const snippet = hunk.content.trim().slice(0, 120);

        findings.push({
          ruleId      : rule.id,
          severity    : rule.severity,
          file        : hunk.file,
          line        : hunk.lineNumber,
          description : rule.description,
          suggestion  : rule.suggestion,
          snippet,
        });
      }
    }
  }

  return findings;
}

// ─── Formatter de comentário Markdown ─────────────────────────────────────────

const SEVERITY_EMOJI = {
  [SEVERITY.CRITICAL] : '🔴',
  [SEVERITY.WARNING]  : '🟡',
  [SEVERITY.INFO]     : '🔵',
};

function formatComment(findings, diffStats) {
  const critical = findings.filter(f => f.severity === SEVERITY.CRITICAL);
  const warnings  = findings.filter(f => f.severity === SEVERITY.WARNING);
  const infos     = findings.filter(f => f.severity === SEVERITY.INFO);

  const hasCritical = critical.length > 0;
  const statusLine  = hasCritical
    ? '## 🤖 AI Review — ❌ BLOQUEADO (findings críticos encontrados)'
    : findings.length > 0
      ? '## 🤖 AI Review — ⚠️ Atenção (melhorias sugeridas)'
      : '## 🤖 AI Review — ✅ Nenhum problema detectado';

  const lines = [statusLine, ''];

  // Resumo
  lines.push('### Resumo');
  lines.push('');
  lines.push(`| Severidade | Quantidade |`);
  lines.push(`|------------|-----------|`);
  lines.push(`| 🔴 CRITICAL | **${critical.length}** |`);
  lines.push(`| 🟡 WARNING  | **${warnings.length}** |`);
  lines.push(`| 🔵 INFO     | **${infos.length}** |`);
  lines.push('');
  lines.push(`> Arquivos analisados: **${diffStats.files}** | Linhas adicionadas: **${diffStats.addedLines}**`);
  lines.push('');

  if (findings.length === 0) {
    lines.push('Nenhum padrão problemático detectado neste PR. ✅');
    lines.push('');
    lines.push('---');
    lines.push('*Análise gerada automaticamente — revise o contexto antes de confiar cegamente.*');
    return lines.join('\n');
  }

  // Detalhes por severidade
  for (const [label, group] of [
    ['🔴 CRITICAL', critical],
    ['🟡 WARNING',  warnings],
    ['🔵 INFO',     infos],
  ]) {
    if (group.length === 0) continue;

    lines.push(`### ${label}`);
    lines.push('');

    for (const f of group) {
      lines.push(`#### \`${f.ruleId}\` — ${f.description}`);
      lines.push('');
      lines.push(`- **Arquivo:** \`${f.file}\` (linha ${f.line})`);
      lines.push(`- **Sugestão:** ${f.suggestion}`);
      lines.push('');
      lines.push('```');
      lines.push(f.snippet);
      lines.push('```');
      lines.push('');
    }
  }

  // Quality gate
  lines.push('---');
  lines.push('### Quality Gate');
  lines.push('');
  if (hasCritical) {
    lines.push('❌ **Este PR está bloqueado.** Corrija todos os findings `CRITICAL` antes de solicitar review humano.');
  } else {
    lines.push('✅ **Quality gate passou.** Findings de WARNING/INFO são sugestões de melhoria, não bloqueiam o merge.');
  }
  lines.push('');
  lines.push('---');
  lines.push('');
  lines.push('<details>');
  lines.push('<summary>ℹ️ Sobre esta análise</summary>');
  lines.push('');
  lines.push('Esta análise é gerada por um script de análise estática baseado em padrões regex.');
  lines.push('Ela **não substitui** o review humano — pode produzir falsos positivos.');
  lines.push('Consulte `ia-cicd-analise.md` para entender quando confiar na IA vs exigir revisão humana.');
  lines.push('');
  lines.push('</details>');

  return lines.join('\n');
}

// ─── Entrypoint ───────────────────────────────────────────────────────────────

function main() {
  const diffFile = process.argv[2];

  if (!diffFile) {
    console.error('[ai-review] Uso: node ai-review.js <diff_file>');
    process.exit(1);
  }

  if (!fs.existsSync(diffFile)) {
    console.error(`[ai-review] Arquivo não encontrado: ${diffFile}`);
    process.exit(1);
  }

  const diffText = fs.readFileSync(diffFile, 'utf8');

  if (!diffText.trim()) {
    console.log('[ai-review] Diff vazio — nenhuma linha adicionada para analisar.');
    // Escreve comentário mínimo
    const comment = '## 🤖 AI Review — ✅ Nenhuma alteração detectada no diff.';
    fs.writeFileSync('ai-review-comment.md', comment, 'utf8');
    process.exit(0);
  }

  const hunks = parseDiff(diffText);

  // Estatísticas do diff
  const uniqueFiles = [...new Set(hunks.map(h => h.file))];
  const diffStats   = { files: uniqueFiles.length, addedLines: hunks.length };

  const findings = analyze(hunks);
  const comment  = formatComment(findings, diffStats);

  // Salva o comentário formatado
  fs.writeFileSync('ai-review-comment.md', comment, 'utf8');

  // Salva o JSON de findings (para uso no workflow)
  const result = {
    summary : {
      critical : findings.filter(f => f.severity === SEVERITY.CRITICAL).length,
      warning  : findings.filter(f => f.severity === SEVERITY.WARNING).length,
      info     : findings.filter(f => f.severity === SEVERITY.INFO).length,
      total    : findings.length,
    },
    diffStats,
    findings,
  };

  fs.writeFileSync('ai-review-result.json', JSON.stringify(result, null, 2), 'utf8');

  // Log no stdout para o workflow
  console.log(JSON.stringify(result, null, 2));

  // Quality gate: exit 1 se houver CRITICAL
  if (result.summary.critical > 0) {
    console.error(`\n[ai-review] ❌ QUALITY GATE FAILED — ${result.summary.critical} finding(s) CRITICAL encontrado(s).`);
    process.exit(1);
  }

  console.error(`\n[ai-review] ✅ QUALITY GATE PASSED — ${result.summary.total} finding(s) (0 CRITICAL).`);
  process.exit(0);
}

main();
