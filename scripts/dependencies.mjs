#!/usr/bin/env node
// 现有协议工具入口；准备实现唯一归 resources.mjs。
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {runDependencyCLI} from './resources.mjs';
if(!process.execArgv.some(value=>/^(?:-e|--eval(?:=|$)|--input-type(?:=|$))/u.test(value)) && process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url))await runDependencyCLI(process.argv.slice(2));
