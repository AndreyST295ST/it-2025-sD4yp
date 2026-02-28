import fs from 'fs';
import babel from '@rollup/plugin-babel';
import json from '@rollup/plugin-json';
import terser from '@rollup/plugin-terser';

const isRelease = process.env.BUILD === 'RELEASE';

const pages = [];

fs.readdirSync('./src', { withFileTypes: true })
  .filter((item) => !item.isDirectory())
  .forEach((item) => {
    pages.push(item.name);
  });

const pluginList = [
  babel({
    babelHelpers: 'bundled',
  }),
  json(),
];

if (isRelease) {
  pluginList.push(terser());
}

const export_page = pages.reduce((acc, item) => {
  acc.push({
    input: `./src/${item}`,
    output: {
      file: `../../server/www/js/${item}`,
      format: 'cjs',
      sourcemap: isRelease ? false : 'inline',
    },
    plugins: pluginList,
  });
  return acc;
}, []);

export default export_page;
