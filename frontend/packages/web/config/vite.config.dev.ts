import baseConfig from './vite.config.base';
import { config } from 'dotenv';
import { mergeConfig } from 'vite';
import eslint from 'vite-plugin-eslint';

// 注入本地/开发配置环境变量(先导入的配置优先级高)
config({ path: ['.env.development.local', '.env.development'] });

export default mergeConfig(
  {
    mode: 'development',
    server: {
      open: true,
      fs: {
        strict: true,
      },
      proxy: {
        // 注意：更具体的路径必须放在前面，否则会被更短的路径先匹配
        '/front/api': {
          target: process.env.VITE_DEV_DOMAIN,
          changeOrigin: true,
          rewrite: (path: string) => {
            const newPath = path.replace(/^\/front/, '');
            console.log(`[Vite Proxy] /front/api: ${path} -> ${newPath}`);
            return newPath;
          },
          configure: (proxy) => {
            proxy.on('proxyReq', (proxyReq, req) => {
              console.log(`[Vite Proxy] Forwarding: ${req.method} ${req.url} -> ${proxyReq.path}`);
            });
          },
        },
        '/front/sse': {
          target: process.env.VITE_DEV_DOMAIN,
          changeOrigin: true,
          rewrite: (path: string) => path.replace(/^\/front/, ''),
        },
        '/front': {
          target: process.env.VITE_DEV_DOMAIN,
          changeOrigin: true,
          rewrite: (path: string) => path.replace(/^\/front/, ''),
        },
        '/api': {
          target: process.env.VITE_DEV_DOMAIN,
          changeOrigin: true,
        },
        '/sse': {
          target: process.env.VITE_DEV_DOMAIN,
          changeOrigin: true,
        },
        '/pic': {
          target: process.env.VITE_DEV_DOMAIN,
          changeOrigin: true,
          rewrite: (path: string) => path.replace(/^\/front\/pic/, ''),
        },
        '/attachment': {
          target: process.env.VITE_DEV_DOMAIN,
          changeOrigin: true,
          rewrite: (path: string) => path.replace(/^\/front\/attachment/, ''),
        },
        '/ui': {
          target: process.env.VITE_DEV_DOMAIN,
          changeOrigin: true,
          rewrite: (path: string) => path.replace(/^\/front\/ui/, ''),
        },
      },
    },
    plugins: [
      eslint({
        overrideConfigFile: 'eslint.config.cjs',
        cache: false,
        include: ['src/**/*.ts', 'src/**/*.tsx', 'src/**/*.vue'],
        exclude: ['node_modules'],
      }),
    ],
  },
  baseConfig
);
