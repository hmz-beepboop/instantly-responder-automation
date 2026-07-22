#!/usr/bin/env node
// Content-safe repository secret scanner: reports only rule names and file
// paths, never matching values. Intended for inbound-console release evidence.

import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] || '.');
const ignoredDirectories = new Set(['.git', 'node_modules', '.agents', '.codex']);
const ignoredExtensions = new Set(['.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.pdf', '.zip', '.gz', '.tgz', '.tar', '.sqlite', '.db']);
const rules = [
  ['private_key', /-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----/],
  ['google_api_key', /AIza[0-9A-Za-z_-]{30,}/],
  ['github_token', /gh[pousr]_[0-9A-Za-z]{30,}/],
  ['slack_token', /xox[baprs]-[0-9A-Za-z-]{20,}/],
  ['openai_style_key', /sk-[A-Za-z0-9_-]{24,}/],
  ['literal_google_chat_webhook', /https:\/\/chat\.googleapis\.com\/[^\s"']*(?:key=|token=)[^\s"']+/],
  ['literal_sensitive_env', /(?:INSTANTLY_API_KEY|HMZ_INSTANTLY_API_KEY|OPENAI_API_KEY|N8N_ENCRYPTION_KEY)\s*[:=]\s*["']([^$<{\s"']{16,})["']/],
];
const findings = [];
let filesScanned = 0;
let bytesScanned = 0;
let skippedLarge = 0;

function visit(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.isSymbolicLink()) continue;
    if (entry.isDirectory()) {
      if (!ignoredDirectories.has(entry.name)) visit(path.join(directory, entry.name));
      continue;
    }
    if (!entry.isFile() || ignoredExtensions.has(path.extname(entry.name).toLowerCase())) continue;
    const file = path.join(directory, entry.name);
    const stat = fs.statSync(file);
    if (stat.size > 20 * 1024 * 1024) { skippedLarge++; continue; }
    const buffer = fs.readFileSync(file);
    if (buffer.includes(0)) continue;
    const text = buffer.toString('utf8');
    filesScanned++;
    bytesScanned += buffer.length;
    for (const [rule, pattern] of rules) {
      const match = pattern.exec(text);
      if (!match) continue;
      if (rule === 'literal_sensitive_env' && /^(?:test|dummy|fake|fixture|placeholder|redacted|not[-_ ]?a[-_ ]?real)|example|test/i.test(match[1])) continue;
      findings.push({ rule, file: path.relative(root, file) });
    }
  }
}

visit(root);
console.log(JSON.stringify({ ok: findings.length === 0, filesScanned, bytesScanned, skippedLarge, findingCount: findings.length, findings }, null, 2));
if (findings.length) process.exitCode = 1;
