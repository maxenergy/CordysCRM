import type { CordysAxios } from '@lib/shared/api/http/Axios';
import {
  GeneratePortraitUrl,
  GetPortraitUrl,
  GenerateScriptUrl,
  GetScriptTemplatesUrl,
  SaveScriptTemplateUrl,
  GetScriptHistoryUrl,
} from '@lib/shared/api/requrls/ai';
import type {
  CompanyPortrait,
  GeneratePortraitParams,
  GenerateScriptParams,
  GeneratedScript,
  ScriptTemplate,
  SaveScriptTemplateParams,
  ScriptHistoryItem,
} from '@lib/shared/models/ai';

export default function useAIApi(CDR: CordysAxios) {
  /**
   * 生成企业画像
   */
  function generatePortrait(data: GeneratePortraitParams) {
    return CDR.post<CompanyPortrait>({ url: GeneratePortraitUrl, data });
  }

  /**
   * 获取企业画像
   */
  function getPortrait(customerId: string) {
    return CDR.get<CompanyPortrait>({ url: `${GetPortraitUrl}/${customerId}` });
  }

  /**
   * 生成话术
   */
  function generateScript(data: GenerateScriptParams) {
    return CDR.post<GeneratedScript>({ url: GenerateScriptUrl, data });
  }

  /**
   * 获取话术模板列表
   */
  function getScriptTemplates() {
    return CDR.get<ScriptTemplate[]>({ url: GetScriptTemplatesUrl });
  }

  /**
   * 保存话术为模板
   */
  function saveScriptTemplate(data: SaveScriptTemplateParams) {
    return CDR.post({ url: SaveScriptTemplateUrl, data });
  }

  /**
   * 获取话术生成历史
   */
  function getScriptHistory(customerId: string) {
    return CDR.get<ScriptHistoryItem[]>({ url: `${GetScriptHistoryUrl}/${customerId}` });
  }

  return {
    generatePortrait,
    getPortrait,
    generateScript,
    getScriptTemplates,
    saveScriptTemplate,
    getScriptHistory,
  };
}
