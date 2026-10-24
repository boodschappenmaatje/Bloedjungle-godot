import {build} from 'esbuild';
import fs from 'node:fs/promises';
await build({entryPoints:['src.js'],bundle:true,format:'esm',minify:true,legalComments:'linked',outfile:'viewer.js'});
// Three's embedded GLSL has harmless trailing spaces; keep generated diffs clean.
const code=await fs.readFile('viewer.js','utf8');
await fs.writeFile('viewer.js',code.replace(/[\t ]+$/gm,''));
