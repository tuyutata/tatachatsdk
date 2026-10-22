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

export const tools=Object.freeze({node:'25.2.1',rust:'1.97.1',flutter:'3.47.2',ndk:'28.2.13676358',protoc:'35.0',protocPlugin:'25.0.0'});
export const repository='tuyutata/tatachatsdk';

// 本产品Workflow坐标声明。
export const workflows=Object.freeze({"sdk":"sdk.yml"});

// 只返回声明数据；派发与观察归通用调用方，版本及交付归本仓YAML。
export function describeAction({flow,platform,inputs={}}){
 const workflow=workflows[platform];
 if(flow==='release'&&workflow)return {repository:"tuyutata/tatachatsdk",workflow,ref:'main',inputs};
 throw Error('本产品未声明该流程：'+flow+'·'+platform);
}
