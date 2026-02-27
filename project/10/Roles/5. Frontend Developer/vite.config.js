import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  server: {
    port: 3000
  },
  css: {
    preprocessorOptions: {
      scss: {
        additionalData: `@import "./src/styles/main.scss";`
      }
    }
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html'),
        signup: resolve(__dirname, 'src/pages/auth/signup.html'),
        signin: resolve(__dirname, 'src/pages/auth/signin.html'),
        'forgot-password': resolve(__dirname, 'src/pages/auth/forgot-password.html'),
        'reset-confirmation': resolve(__dirname, 'src/pages/auth/reset-confirmation.html'),
        'new-password': resolve(__dirname, 'src/pages/auth/new-password.html'),
        explore: resolve(__dirname, 'src/pages/app/explore.html'),
        preferences: resolve(__dirname, 'src/pages/app/preferences.html'),
        profile: resolve(__dirname, 'src/pages/app/profile.html'),
        'game-detail': resolve(__dirname, 'src/pages/app/game-detail.html')
      }
    }
  }
});