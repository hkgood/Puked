---
layout: default
title: Puked - 让舒适度可量化
---

<style>
  /* 隐藏 Minimal 主题自带的侧边栏、默认页脚和所有多余元素 */
  header, .site-footer, footer { display: none !important; }
  
  /* 调整主容器 */
  section { 
    width: 100% !important; 
    float: none !important; 
    margin: 0 auto !important; 
    max-width: 800px !important; 
    padding-bottom: 150px !important; /* 为底部固定栏留出空间 */
  }
  .wrapper { max-width: 800px !important; margin: 0 auto !important; padding: 20px !important; }
  
  /* 注入 Apple 风格的微调 */
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; color: #1d1d1f; }
  h1 { font-weight: 700; font-size: 3.5rem; letter-spacing: -0.05rem; margin-bottom: 0.5rem; color: #1d1d1f; }
  .subtitle { font-size: 1.5rem; color: #86868b; margin-bottom: 2.5rem; font-weight: 400; }
  
  .cta-button {
    display: inline-block;
    background: #0071e3;
    color: white !important;
    padding: 12px 28px;
    border-radius: 980px;
    font-weight: 600;
    font-size: 1.1rem;
    text-decoration: none;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  }
  .cta-button:hover { background: #0077ed; transform: scale(1.05); }
  
  .screenshot-group { display: flex; justify-content: space-between; gap: 15px; margin: 4rem 0; }
  .screenshot-group img { border-radius: 22px; box-shadow: 0 20px 40px rgba(0,0,0,0.1); width: 31%; transition: transform 0.5s ease; }
  .screenshot-group img:hover { transform: translateY(-10px); }
  
  .feature-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 3rem; margin-top: 5rem; text-align: left; }
  .feature-item h3 { margin-bottom: 0.8rem; font-size: 1.2rem; font-weight: 600; }
  .feature-item p { color: #86868b; font-size: 1rem; line-height: 1.6; }

  /* Apple 风格底部固定栏 */
  .custom-sticky-footer {
    position: fixed;
    bottom: 0;
    left: 0;
    width: 100%;
    background: rgba(255, 255, 255, 0.85);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border-top: 1px solid rgba(210, 210, 215, 0.5);
    padding: 20px 0;
    z-index: 9999;
    text-align: center;
    font-size: 0.85rem;
    color: #86868b;
  }
  .custom-sticky-footer a { color: #0071e3; text-decoration: none; margin: 0 10px; }
</style>

<div align="center" style="padding-top: 6rem;">
  <img src="assets/images/logo.png" width="120" style="margin-bottom: 2rem;" alt="Puked Logo" />
  <h1>Puked.</h1>
  <p class="subtitle">让行驶舒适度，从主观感受变为精密数据。</p>
  
  <a href="https://github.com/hkgood/Puked/releases/latest" class="cta-button">免费下载 APK</a>
  <p style="margin-top: 1.5rem; font-size: 0.9rem; color: #86868b;">支持 Android 10.0+ · 100Hz 采样精度</p>

  <div class="screenshot-group">
    <img src="assets/images/01.jpg" alt="Recording View" />
    <img src="assets/images/02.jpg" alt="Map View" />
    <img src="assets/images/03.jpg" alt="History View" />
  </div>

  <div class="feature-grid">
    <div class="feature-item">
      <h3>精密采样</h3>
      <p>100Hz 高频引擎，深度提取加速度计与陀螺仪原始数据，捕捉每一次细微震动。</p>
    </div>
    <div class="feature-item">
      <h3>自动校准</h3>
      <p>无视手机摆放角度。静态重力对齐算法自动将数据投影至车辆坐标系。</p>
    </div>
    <div class="feature-item">
      <h3>回溯记录</h3>
      <p>感知不适瞬间，点击即可捕获前 10 秒真值。为算法迭代提供最真实的主观标定。</p>
    </div>
    <div class="feature-item">
      <h3>极致审美</h3>
      <p>专为车内交互设计的深色 UI 与全方位触觉反馈。毛玻璃元素，让专注回归驾驶本身。</p>
    </div>
  </div>
</div>

<div class="custom-sticky-footer">
  <p>
    基于 GPL-3.0 开源 · 隐私第一 · 所有数据本地存储<br>
    <a href="https://github.com/hkgood/Puked">GitHub 源代码</a> | 
    <a href="mailto:support@puked.app">反馈建议</a>
    <br>
    © 2024 Puked Team.
  </p>
</div>
