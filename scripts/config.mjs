// 本产品配置需求的公开入口；只登记名称、类型和规则，不保存配置值。
export const manifest=Object.freeze({
  "schema": 1,
  "product_id": "tatachatsdk",
  "configuration": {
    "id": "tatachatsdk",
    "kind": "software",
    "title": "塔塔聊天配置",
    "items": []
  }
});
export function describeConfiguration(){return JSON.parse(JSON.stringify(manifest));}

// 编译与自动化共用本产品声明，不依赖控制台模块。
export const tools=Object.freeze({node:'25.2.1',rust:'1.97.1',flutter:'3.47.2',ndk:'28.2.13676358',protoc:'35.0',protocPlugin:'25.0.0'});
export const repository='tuyutata/tatachatsdk';

// 这里只声明本仓执行入口；版本、网络、轮询及清理全部归既有build脚本。
import {automate,cleanupRuns} from './build.mjs';
export function describeAction({flow,platform}){
 if(!['release','cleanup'].includes(flow)||platform!=='sdk')throw Error('本产品尚未声明该流程入口：'+flow+'·'+platform);
 return {repository,launch:flow==='cleanup'?cleanupRuns:automate};
}
