/**
 * AI 模块类型定义
 */

// 画像基本信息
export interface PortraitBasicInfo {
  industry: string;
  scale: string;
  mainProducts: string;
  foundedYear: string;
  employeeCount: string;
  annualRevenue: string;
}

// 商机洞察
export interface BusinessInsight {
  title: string;
  description: string;
  confidence: number;
  source: string;
}

// 风险级别
export type RiskLevel = 'high' | 'medium' | 'low';

// 风险提示
export interface RiskAlert {
  title: string;
  description: string;
  level: RiskLevel;
}

// 情感倾向
export type Sentiment = 'positive' | 'negative' | 'neutral';

// 舆情信息
export interface PublicOpinion {
  title: string;
  source: string;
  sentiment: Sentiment;
  publishDate?: string;
}

// 企业画像
export interface CompanyPortrait {
  id: string;
  customerId: string;
  basicInfo: PortraitBasicInfo;
  insights: BusinessInsight[];
  risks: RiskAlert[];
  opinions: PublicOpinion[];
  generatedAt: string;
  updatedAt: string;
}

// 生成画像参数
export interface GeneratePortraitParams {
  customerId: string;
  refresh?: boolean;
}

// 话术场景
export type ScriptScene = 'first_contact' | 'product_intro' | 'meeting_invite' | 'follow_up';

// 话术渠道
export type ScriptChannel = 'phone' | 'wechat' | 'email';

// 话术语气
export type ScriptTone = 'professional' | 'enthusiastic' | 'concise';

// 生成话术参数
export interface GenerateScriptParams {
  customerId: string;
  scene: ScriptScene;
  channel: ScriptChannel;
  tone: ScriptTone;
  templateId?: string;
}

// 生成的话术
export interface GeneratedScript {
  id: string;
  content: string;
  scene: ScriptScene;
  channel: ScriptChannel;
  tone: ScriptTone;
  createdAt: string;
}

// 话术模板
export interface ScriptTemplate {
  id: string;
  name: string;
  industry?: string;
  scene: ScriptScene;
  channel: ScriptChannel;
  tone: ScriptTone;
  content: string;
  isSystem: boolean;
  enabled: boolean;
  createdAt: string;
}

// 保存话术模板参数
export interface SaveScriptTemplateParams {
  name: string;
  content: string;
  scene: ScriptScene;
  channel: ScriptChannel;
  tone: ScriptTone;
  industry?: string;
}

// 话术历史记录
export interface ScriptHistoryItem {
  id: string;
  content: string;
  scene: ScriptScene;
  channel: ScriptChannel;
  tone: ScriptTone;
  createdAt: string;
}

// 场景标签映射
export const SceneLabels: Record<ScriptScene, string> = {
  first_contact: '首次接触',
  product_intro: '产品介绍',
  meeting_invite: '邀约会议',
  follow_up: '跟进回访',
};

// 渠道标签映射
export const ChannelLabels: Record<ScriptChannel, string> = {
  phone: '电话',
  wechat: '微信',
  email: '邮件',
};

// 语气标签映射
export const ToneLabels: Record<ScriptTone, string> = {
  professional: '专业',
  enthusiastic: '热情',
  concise: '简洁',
};

// 风险级别标签映射
export const RiskLevelLabels: Record<RiskLevel, string> = {
  high: '高风险',
  medium: '中风险',
  low: '低风险',
};

// 情感标签映射
export const SentimentLabels: Record<Sentiment, string> = {
  positive: '正面',
  negative: '负面',
  neutral: '中性',
};
