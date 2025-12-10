import { defineConfig } from 'vite';
import { resolve } from 'path';
import { copyFileSync, mkdirSync, existsSync } from 'fs';

// 复制静态文件到 dist 目录
function copyStaticFiles() {
  return {
    name: 'copy-static-files',
    closeBundle() {
      const distDir = resolve(__dirname, 'dist');
      
      // 复制 manifest.json
      copyFileSync(
        resolve(__dirname, 'manifest.json'),
        resolve(distDir, 'manifest.json')
      );
      
      // 复制 content.css
      if (existsSync(resolve(__dirname, 'src/content/content.css'))) {
        copyFileSync(
          resolve(__dirname, 'src/content/content.css'),
          resolve(distDir, 'content.css')
        );
      }
      
      // 创建 assets/icons 目录
      const iconsDir = resolve(distDir, 'assets/icons');
      if (!existsSync(iconsDir)) {
        mkdirSync(iconsDir, { recursive: true });
      }
      
      // 复制图标文件（如果存在）
      const iconSizes = ['16', '48', '128'];
      iconSizes.forEach(size => {
        const iconPath = resolve(__dirname, `public/assets/icons/icon${size}.png`);
        if (existsSync(iconPath)) {
          copyFileSync(iconPath, resolve(iconsDir, `icon${size}.png`));
        }
      });
      
      console.log('Static files copied to dist/');
    }
  };
}

export default defineConfig({
  build: {
    outDir: resolve(__dirname, 'dist'),
    emptyOutDir: true,
    rollupOptions: {
      input: {
        popup: resolve(__dirname, 'src/popup/popup.html'),
        background: resolve(__dirname, 'src/background/background.ts'),
        content: resolve(__dirname, 'src/content/content.ts'),
      },
      output: {
        entryFileNames: (chunkInfo) => {
          if (chunkInfo.name === 'background') {
            return 'background.js';
          }
          if (chunkInfo.name === 'content') {
            return 'content.js';
          }
          return '[name].js';
        },
        chunkFileNames: 'assets/[name]-[hash].js',
        assetFileNames: (assetInfo) => {
          // 保持 CSS 文件名不带 hash，方便 manifest 引用
          if (assetInfo.name?.endsWith('.css')) {
            return 'assets/[name][extname]';
          }
          return 'assets/[name]-[hash][extname]';
        },
      },
    },
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },
  plugins: [copyStaticFiles()],
});
