package cn.cordys.crm.integration.ai.provider;

import cn.cordys.crm.integration.ai.LLMProvider;
import cn.cordys.crm.integration.ai.LLMRequest;
import cn.cordys.crm.integration.ai.LLMResponse;
import cn.cordys.crm.integration.ai.ProviderType;
import org.springframework.stereotype.Component;

/**
 * Mock LLM 提供商实现
 * 用于开发和测试环境
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Component
public class MockLLMProvider implements LLMProvider {

    private static final String MOCK_MODEL = "mock-gpt-4";

    @Override
    public ProviderType getProviderType() {
        return ProviderType.LOCAL;
    }

    @Override
    public LLMResponse generate(LLMRequest request) {
        // 模拟生成企业画像响应
        String mockResponse = generateMockPortraitResponse();
        
        return LLMResponse.builder()
                .content(mockResponse)
                .model(MOCK_MODEL)
                .promptTokens(estimateTokens(request.getPrompt()))
                .completionTokens(estimateTokens(mockResponse))
                .success(true)
                .build();
    }

    private String generateMockPortraitResponse() {
        return """
            {
              "basics": {
                "industry": "信息技术服务业",
                "scale": "中型企业，员工规模100-500人",
                "mainProducts": "企业级软件开发、系统集成服务"
              },
              "opportunities": [
                {
                  "title": "数字化转型需求",
                  "confidence": 0.85,
                  "source": "行业发展趋势分析"
                },
                {
                  "title": "云服务迁移机会",
                  "confidence": 0.72,
                  "source": "企业规模与业务特征"
                }
              ],
              "risks": [
                {
                  "level": "低",
                  "text": "财务状况稳健，无明显风险"
                }
              ],
              "sentiments": [
                {
                  "title": "行业口碑良好",
                  "source": "公开信息分析",
                  "sentiment": "正面"
                }
              ]
            }
            """;
    }

    private int estimateTokens(String text) {
        if (text == null) {
            return 0;
        }
        // 简单估算：中文约1.5字符/token，英文约4字符/token
        return text.length() / 2;
    }
}
