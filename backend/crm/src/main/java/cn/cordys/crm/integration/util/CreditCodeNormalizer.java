package cn.cordys.crm.integration.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * 企业信用代码规范化器
 * 
 * 职责：标准化企业统一社会信用代码格式，确保数据一致性
 * 
 * 规范化规则：
 * 1. null 或空字符串 → 返回 null
 * 2. 全角字符转半角（A-Z, 0-9, 空格）
 * 3. Trim 首尾空白
 * 4. 转换为大写
 * 5. 验证格式（18位字母数字）
 * 
 * @author CordysCRM
 * @since 1.6.0
 */
@Component
public class CreditCodeNormalizer {
    
    private static final Logger logger = LoggerFactory.getLogger(CreditCodeNormalizer.class);
    
    /**
     * 信用代码标准长度
     */
    private static final int STANDARD_LENGTH = 18;
    
    /**
     * 信用代码格式正则（18位字母数字）
     */
    private static final String VALID_PATTERN = "^[0-9A-Z]{18}$";
    
    /**
     * 规范化信用代码
     * 
     * @param creditCode 原始信用代码
     * @return 规范化后的信用代码，如果输入为 null 或空则返回 null
     */
    public String normalize(String creditCode) {
        // 规则1: null 或空字符串 → 返回 null
        if (creditCode == null || creditCode.trim().isEmpty()) {
            return null;
        }
        
        try {
            // 规则2: 先转换全角空格，再 Trim
            String normalized = convertFullWidthToHalfWidth(creditCode);
            normalized = normalized.trim();
            
            // 规则3: 转换为大写
            normalized = normalized.toUpperCase();
            
            // 规则5: 验证格式
            if (!normalized.matches(VALID_PATTERN)) {
                logger.warn("Invalid credit code format after normalization: original='{}', normalized='{}'", 
                           creditCode, normalized);
                // 返回规范化结果，但记录警告
                // 这允许系统处理历史数据中的非标准格式
            }
            
            return normalized;
            
        } catch (Exception e) {
            logger.error("Failed to normalize credit code: '{}'", creditCode, e);
            // 返回 null 以保持一致性，避免存储未规范化的值
            return null;
        }
    }
    
    /**
     * 将全角字符转换为半角字符
     * 
     * 支持的字符：
     * - 全角字母 A-Z (Ａ-Ｚ) → 半角 A-Z
     * - 全角数字 0-9 (０-９) → 半角 0-9
     * 
     * @param input 输入字符串
     * @return 转换后的字符串
     */
    private String convertFullWidthToHalfWidth(String input) {
        if (input == null || input.isEmpty()) {
            return input;
        }
        
        StringBuilder result = new StringBuilder(input.length());
        
        for (int i = 0; i < input.length(); i++) {
            char c = input.charAt(i);
            
            // 全角字母 A-Z (Unicode: 0xFF21-0xFF3A)
            if (c >= 'Ａ' && c <= 'Ｚ') {
                result.append((char) (c - 'Ａ' + 'A'));
            }
            // 全角数字 0-9 (Unicode: 0xFF10-0xFF19)
            else if (c >= '０' && c <= '９') {
                result.append((char) (c - '０' + '0'));
            }
            // 全角空格 (Unicode: 0x3000)
            else if (c == '　') {
                result.append(' ');
            }
            // 其他字符保持不变
            else {
                result.append(c);
            }
        }
        
        return result.toString();
    }
    
    /**
     * 验证信用代码格式是否有效
     * 
     * @param creditCode 信用代码
     * @return true 如果格式有效，false 否则
     */
    public boolean isValid(String creditCode) {
        if (creditCode == null || creditCode.isEmpty()) {
            return false;
        }
        
        String normalized = normalize(creditCode);
        return normalized != null && normalized.matches(VALID_PATTERN);
    }
}
