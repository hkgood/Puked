import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
  ],
  build: {
    // 🔥 P1-2 修复：代码分割，避免单个 JS 文件过大导致 HTTP/2 连接问题
    rollupOptions: {
      output: {
        manualChunks: {
          // 第三方库按需分组
          'vendor-react': ['react', 'react-dom'],
          'vendor-pocketbase': ['pocketbase'],
          'vendor-utils': ['lucide-react'],
        },
      },
    },
  },
})
