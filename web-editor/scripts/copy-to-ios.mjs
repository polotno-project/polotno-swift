import { cpSync, existsSync, mkdirSync, readdirSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFileSync, writeFileSync } from 'node:fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, '..');
const distDir = join(projectRoot, 'dist');
const iosEditorDir = join(projectRoot, '..', 'PolotnoSwift', 'Editor');

if (!existsSync(distDir)) {
  console.error('Missing dist folder. Run `npm run build` first.');
  process.exit(1);
}

if (!existsSync(iosEditorDir)) {
  mkdirSync(iosEditorDir, { recursive: true });
}

for (const entry of readdirSync(iosEditorDir)) {
  rmSync(join(iosEditorDir, entry), { recursive: true, force: true });
}

for (const entry of readdirSync(distDir)) {
  const source = join(distDir, entry);
  const destination = join(iosEditorDir, entry);
  cpSync(source, destination, { recursive: true });
}

const indexPath = join(iosEditorDir, 'index.html');
if (existsSync(indexPath)) {
  const html = readFileSync(indexPath, 'utf8');
  const patched = html.replaceAll(' crossorigin', '');
  writeFileSync(indexPath, patched, 'utf8');
}

console.log(`Copied ${distDir} -> ${iosEditorDir}`);

