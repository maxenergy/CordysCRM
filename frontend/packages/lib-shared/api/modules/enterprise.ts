import type { CordysAxios } from '@lib/shared/api/http/Axios';
import {
  SearchEnterpriseUrl,
  ImportEnterpriseUrl,
  CheckEnterpriseUrl,
} from '@lib/shared/api/requrls/enterprise';
import type {
  EnterpriseSearchResult,
  EnterpriseImportParams,
  EnterpriseImportResponse,
  EnterpriseCheckResult,
} from '@lib/shared/models/enterprise';

export default function useEnterpriseApi(CDR: CordysAxios) {
  /**
   * 搜索企业
   */
  function searchEnterprise(keyword: string) {
    return CDR.get<EnterpriseSearchResult[]>({
      url: SearchEnterpriseUrl,
      params: { keyword },
    });
  }

  /**
   * 导入企业
   */
  function importEnterprise(data: EnterpriseImportParams) {
    return CDR.post<EnterpriseImportResponse>({
      url: ImportEnterpriseUrl,
      data,
    });
  }

  /**
   * 检查企业是否已存在
   */
  function checkEnterprise(creditCode: string) {
    return CDR.get<EnterpriseCheckResult>({
      url: CheckEnterpriseUrl,
      params: { creditCode },
    });
  }

  return {
    searchEnterprise,
    importEnterprise,
    checkEnterprise,
  };
}
