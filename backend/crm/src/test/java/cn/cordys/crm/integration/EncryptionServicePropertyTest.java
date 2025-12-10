package cn.cordys.crm.integration;

import cn.cordys.crm.integration.service.EncryptionService;
import net.jqwik.api.*;
import net.jqwik.api.constraints.NotBlank;
import net.jqwik.api.constraints.StringLength;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Property-Based Tests for EncryptionService
 * 
 * **Feature: crm-mobile-enterprise-ai, Property 26: 凭证加密存储**
 * **Validates: Requirements 8.2, 9.1**
 * 
 * For any third-party service credential stored in the database,
 * the stored value should be encrypted ciphertext, and can be correctly decrypted.
 */
public class EncryptionServicePropertyTest {

    private final EncryptionService encryptionService;

    public EncryptionServicePropertyTest() {
        encryptionService = new EncryptionService();
        // Set encryption key via reflection for testing
        ReflectionTestUtils.setField(encryptionService, "encryptionKey", "TestEncryptionKey-32BytesLong!!");
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 26: 凭证加密存储**
     * **Validates: Requirements 8.2, 9.1**
     * 
     * For any plaintext credential, encrypting and then decrypting
     * should return the original plaintext.
     */
    @Property(tries = 100)
    void encryptDecryptRoundTrip(
            @ForAll @NotBlank @StringLength(min = 1, max = 500) String plainText
    ) {
        // Encrypt
        String encrypted = encryptionService.encrypt(plainText);

        // Verify encrypted text is different from plaintext
        assertThat(encrypted).isNotEqualTo(plainText);

        // Verify encrypted text has correct format (IV:ciphertext)
        assertThat(encrypted).contains(":");

        // Decrypt
        String decrypted = encryptionService.decrypt(encrypted);

        // Verify round-trip consistency
        assertThat(decrypted).isEqualTo(plainText);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 26: 凭证加密存储**
     * **Validates: Requirements 8.2, 9.1**
     * 
     * For any credential, the encrypted value should be valid Base64 format.
     */
    @Property(tries = 100)
    void encryptedTextIsValidFormat(
            @ForAll @NotBlank @StringLength(min = 1, max = 200) String plainText
    ) {
        String encrypted = encryptionService.encrypt(plainText);

        // Verify format is IV:ciphertext
        String[] parts = encrypted.split(":");
        assertThat(parts).hasSize(2);

        // Verify both parts are valid Base64
        assertThat(encryptionService.isValidEncryptedText(encrypted)).isTrue();
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 26: 凭证加密存储**
     * **Validates: Requirements 8.2, 9.1**
     * 
     * For any two different plaintexts, their encrypted values should be different.
     */
    @Property(tries = 100)
    void differentPlaintextsProduceDifferentCiphertexts(
            @ForAll @NotBlank @StringLength(min = 1, max = 100) String plainText1,
            @ForAll @NotBlank @StringLength(min = 1, max = 100) String plainText2
    ) {
        Assume.that(!plainText1.equals(plainText2));

        String encrypted1 = encryptionService.encrypt(plainText1);
        String encrypted2 = encryptionService.encrypt(plainText2);

        // Different plaintexts should produce different ciphertexts
        assertThat(encrypted1).isNotEqualTo(encrypted2);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 26: 凭证加密存储**
     * **Validates: Requirements 8.2, 9.1**
     * 
     * For the same plaintext encrypted twice, the ciphertexts should be different
     * (due to random IV), but both should decrypt to the same plaintext.
     */
    @Property(tries = 100)
    void samePlaintextProducesDifferentCiphertextsButDecryptsCorrectly(
            @ForAll @NotBlank @StringLength(min = 1, max = 100) String plainText
    ) {
        String encrypted1 = encryptionService.encrypt(plainText);
        String encrypted2 = encryptionService.encrypt(plainText);

        // Same plaintext should produce different ciphertexts (random IV)
        assertThat(encrypted1).isNotEqualTo(encrypted2);

        // Both should decrypt to the same plaintext
        assertThat(encryptionService.decrypt(encrypted1)).isEqualTo(plainText);
        assertThat(encryptionService.decrypt(encrypted2)).isEqualTo(plainText);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 26: 凭证加密存储**
     * **Validates: Requirements 8.2, 9.1**
     * 
     * For typical credential formats (API keys, cookies, tokens),
     * encryption and decryption should work correctly.
     */
    @Property(tries = 100)
    void typicalCredentialFormatsWorkCorrectly(
            @ForAll("typicalCredentials") String credential
    ) {
        String encrypted = encryptionService.encrypt(credential);
        String decrypted = encryptionService.decrypt(encrypted);

        assertThat(decrypted).isEqualTo(credential);
    }

    /**
     * **Feature: crm-mobile-enterprise-ai, Property 26: 凭证加密存储**
     * **Validates: Requirements 8.2, 9.1**
     * 
     * Null and empty inputs should be handled gracefully.
     */
    @Example
    void nullAndEmptyInputsHandledGracefully() {
        assertThat(encryptionService.encrypt(null)).isNull();
        assertThat(encryptionService.encrypt("")).isNull();
        assertThat(encryptionService.encrypt("   ")).isNull();

        assertThat(encryptionService.decrypt(null)).isNull();
        assertThat(encryptionService.decrypt("")).isNull();
        assertThat(encryptionService.decrypt("   ")).isNull();
    }

    @Provide
    Arbitrary<String> typicalCredentials() {
        return Arbitraries.of(
                // API Keys
                "sk-1234567890abcdefghijklmnopqrstuvwxyz",
                "AKIAIOSFODNN7EXAMPLE",
                "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
                // JWT Tokens
                "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c",
                // Cookies
                "session_id=abc123def456; user_token=xyz789",
                "BAIDUID=1234567890ABCDEF:FG=1; BIDUPSID=1234567890ABCDEF",
                // Connection strings
                "mysql://user:password@localhost:3306/database",
                "redis://default:password@redis-12345.c1.us-east-1-2.ec2.cloud.redislabs.com:12345",
                // Chinese characters
                "用户名=测试用户&密码=Test123!@#",
                // Special characters
                "key=value&special=!@#$%^&*()_+-=[]{}|;':\",./<>?"
        );
    }
}
