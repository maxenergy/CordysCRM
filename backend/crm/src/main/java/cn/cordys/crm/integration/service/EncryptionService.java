package cn.cordys.crm.integration.service;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang3.StringUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;

/**
 * AES-256 加密服务
 * 用于加密存储第三方服务凭证（爱企查Cookie、AI API Key等）
 * 
 * Requirements: 8.2, 8.4, 9.1
 * 
 * @author cordys
 * @date 2025-12-10
 */
@Service
public class EncryptionService {

    private static final String AES_ALGORITHM = "AES";
    private static final String AES_GCM_TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int GCM_TAG_LENGTH = 128;
    private static final int GCM_IV_LENGTH = 12;
    private static final int AES_KEY_SIZE = 256;

    /**
     * 加密密钥，从配置文件读取
     * 密钥长度必须为32字节（256位）
     */
    @Value("${integration.encryption.key:CordysCRM-Integration-SecretKey}")
    private String encryptionKey;

    /**
     * AES-256-GCM 加密
     *
     * @param plainText 明文
     * @return 加密后的Base64字符串（格式：IV:密文）
     */
    public String encrypt(String plainText) {
        if (StringUtils.isBlank(plainText)) {
            return null;
        }

        try {
            // 生成随机IV
            byte[] iv = generateIv();

            // 准备密钥
            SecretKeySpec keySpec = getSecretKeySpec();

            // 初始化加密器
            Cipher cipher = Cipher.getInstance(AES_GCM_TRANSFORMATION);
            GCMParameterSpec gcmSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, gcmSpec);

            // 加密
            byte[] encryptedBytes = cipher.doFinal(plainText.getBytes(StandardCharsets.UTF_8));

            // 返回格式：Base64(IV):Base64(密文)
            String ivBase64 = Base64.encodeBase64String(iv);
            String cipherBase64 = Base64.encodeBase64String(encryptedBytes);
            return ivBase64 + ":" + cipherBase64;

        } catch (Exception e) {
            throw new RuntimeException("AES-256-GCM encryption failed", e);
        }
    }

    /**
     * AES-256-GCM 解密
     *
     * @param encryptedText 加密后的Base64字符串（格式：IV:密文）
     * @return 解密后的明文
     */
    public String decrypt(String encryptedText) {
        if (StringUtils.isBlank(encryptedText)) {
            return null;
        }

        try {
            // 解析IV和密文
            String[] parts = encryptedText.split(":");
            if (parts.length != 2) {
                throw new IllegalArgumentException("Invalid encrypted text format");
            }

            byte[] iv = Base64.decodeBase64(parts[0]);
            byte[] cipherBytes = Base64.decodeBase64(parts[1]);

            // 准备密钥
            SecretKeySpec keySpec = getSecretKeySpec();

            // 初始化解密器
            Cipher cipher = Cipher.getInstance(AES_GCM_TRANSFORMATION);
            GCMParameterSpec gcmSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
            cipher.init(Cipher.DECRYPT_MODE, keySpec, gcmSpec);

            // 解密
            byte[] decryptedBytes = cipher.doFinal(cipherBytes);
            return new String(decryptedBytes, StandardCharsets.UTF_8);

        } catch (Exception e) {
            throw new RuntimeException("AES-256-GCM decryption failed", e);
        }
    }

    /**
     * 验证加密文本是否有效
     *
     * @param encryptedText 加密文本
     * @return 是否有效
     */
    public boolean isValidEncryptedText(String encryptedText) {
        if (StringUtils.isBlank(encryptedText)) {
            return false;
        }
        try {
            String[] parts = encryptedText.split(":");
            if (parts.length != 2) {
                return false;
            }
            // 尝试解码验证格式
            Base64.decodeBase64(parts[0]);
            Base64.decodeBase64(parts[1]);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * 生成新的AES-256密钥
     *
     * @return Base64编码的密钥
     */
    public static String generateKey() {
        try {
            KeyGenerator keyGen = KeyGenerator.getInstance(AES_ALGORITHM);
            keyGen.init(AES_KEY_SIZE, new SecureRandom());
            SecretKey secretKey = keyGen.generateKey();
            return Base64.encodeBase64String(secretKey.getEncoded());
        } catch (Exception e) {
            throw new RuntimeException("Failed to generate AES-256 key", e);
        }
    }

    /**
     * 生成随机IV
     */
    private byte[] generateIv() {
        byte[] iv = new byte[GCM_IV_LENGTH];
        new SecureRandom().nextBytes(iv);
        return iv;
    }

    /**
     * 获取密钥规格
     * 将配置的密钥转换为32字节的AES-256密钥
     */
    private SecretKeySpec getSecretKeySpec() {
        byte[] keyBytes = normalizeKey(encryptionKey);
        return new SecretKeySpec(keyBytes, AES_ALGORITHM);
    }

    /**
     * 规范化密钥长度为32字节
     * 如果密钥过短则填充，过长则截断
     */
    private byte[] normalizeKey(String key) {
        byte[] keyBytes = key.getBytes(StandardCharsets.UTF_8);
        byte[] normalizedKey = new byte[32]; // 256 bits = 32 bytes

        if (keyBytes.length >= 32) {
            System.arraycopy(keyBytes, 0, normalizedKey, 0, 32);
        } else {
            System.arraycopy(keyBytes, 0, normalizedKey, 0, keyBytes.length);
            // 填充剩余部分
            for (int i = keyBytes.length; i < 32; i++) {
                normalizedKey[i] = (byte) (i % 256);
            }
        }
        return normalizedKey;
    }
}
