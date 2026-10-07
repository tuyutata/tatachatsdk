#!/usr/bin/env node
// 测试库只取本轮锁定Pub坐标；禁止默认HOME缓存及目录扫描回退。
import {lstatSync, readFileSync, realpathSync} from 'node:fs';
import {isAbsolute, join, relative, resolve, sep} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';

function ordinary(path, directory=false) {
  if(typeof path!=='string'||!isAbsolute(path)||resolve(path)!==path)throw Error('测试原生库路径无效');
  const stat=lstatSync(path,{throwIfNoEntry:false});
  if(!(directory?stat?.isDirectory():stat?.isFile())||stat.isSymbolicLink()||realpathSync(path)!==path)throw Error('测试原生库不是本轮普通文件或目录');
  return path;
}
function inside(root,path) {
  const rel=relative(root,path);
  if(!rel||rel==='..'||rel.startsWith('..'+sep)||isAbsolute(rel))throw Error('测试原生库越出本轮缓存');
}
function host(platform,arch) {
  if(platform==='linux'&&arch==='x64')return {isar:'linux/libisar.so'};
  if(platform==='darwin'&&(arch==='arm64'||arch==='x64'))return {isar:'macos/libisar.dylib'};
  throw Error('测试原生库宿主不受支持');
}
export function isarCorePath(configPath,pubCache,lockPath,platform=process.platform,arch=process.arch) {
  ordinary(configPath); ordinary(pubCache,true); ordinary(lockPath);
  const lock=readFileSync(lockPath,'utf8');
  const blocks=[...lock.matchAll(/^  isar_community_flutter_libs:\n(?:[ \t]{4,}[^\n]*\n)+/gm)];
  if(blocks.length!==1||!/^    source: hosted$/m.test(blocks[0][0]))throw Error('Isar锁定包无效');
  const versions=[...blocks[0][0].matchAll(/^    version: "([0-9]+\.[0-9]+\.[0-9]+)"$/gm)];
  if(versions.length!==1)throw Error('Isar锁定版本不唯一');
  const config=JSON.parse(readFileSync(configPath,'utf8'));
  const packages=Array.isArray(config.packages)?config.packages.filter(p=>p.name==='isar_community_flutter_libs'):[];
  if(config.configVersion!==2||packages.length!==1||typeof packages[0].rootUri!=='string')throw Error('Isar本轮包坐标不唯一');
  const url=new URL(packages[0].rootUri,pathToFileURL(configPath));
  if(url.protocol!=='file:'||url.search||url.hash)throw Error('Isar本轮包坐标无效');
  const root=ordinary(fileURLToPath(url).replace(/[\/]$/u,''),true);
  inside(pubCache,root);
  const expected=join(pubCache,'hosted','pub.dev','isar_community_flutter_libs-'+versions[0][1]);
  if(root!==expected)throw Error('Isar包坐标与锁定缓存不一致');
  const manifest=readFileSync(ordinary(join(root,'pubspec.yaml')),'utf8');
  if(!/^name: isar_community_flutter_libs$/m.test(manifest)||!new RegExp('^version: '+versions[0][1].replaceAll('.','\\.')+'$','m').test(manifest))throw Error('Isar包身份与锁不一致');
  return ordinary(join(root,host(platform,arch).isar));
}
if(process.argv[1]&&pathToFileURL(resolve(process.argv[1])).href===import.meta.url) {
  const [command,...args]=process.argv.slice(2);
  if(command==='isar'&&args.length===3)process.stdout.write(isarCorePath(...args));
  else throw Error('测试原生库入口参数无效');
}
