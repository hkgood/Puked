---
layout: default
title: Puked - 让舒适度可量化
---

<style>
  /* 注入一些 Apple 风格的微调 */
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
  h1 { font-weight: 700; font-size: 2.5rem; letter-spacing: -0.05rem; margin-bottom: 0.5rem; }
  .subtitle { font-size: 1.25rem; color: #86868b; margin-bottom: 2rem; }
  .cta-button {
    display: inline-block;
    background: #0071e3;
    color: white !important;
    padding: 12px 24px;
    border-radius: 980px;
    font-weight: 600;
    text-decoration: none;
    transition: all 0.2s ease;
  }
  .cta-button:hover { background: #0077ed; transform: scale(1.02); }
  .screenshot-group { display: flex; justify-content: space-between; gap: 10px; margin: 3rem 0; }
  .screenshot-group img { border-radius: 18px; box-shadow: 0 10px 30px rgba(0,0,0,0.1); width: 31%; }
  .feature-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 2rem; margin-top: 4rem; text-align: left; }
  .feature-item h3 { margin-bottom: 0.5rem; font-size: 1.1rem; }
  .feature-item p { color: #86868b; font-size: 0.95rem; line-height: 1.5; }
</style>

<div align="center" style="margin-top: 4rem;">
  <img src="assets/images/logo.png" width="100" alt="Puked Logo" />
  <h1>Puked.</h1>
  <p class="subtitle">让行驶舒适度，从主观感受变为精密数据。</p>
  
  <a href="https://github.com/maxliu/Puked/releases/latest" class="cta-button">免费下载 APK</a>
  <p style="margin-top: 1rem; font-size: 0.8rem; color: #86868b;">支持 Android 10.0+ · 100Hz 采样精度</p>

  <div class="screenshot-group">
    <img src="assets/images/01.jpg" alt="Screenshot 1" />
    <img src="assets/images/02.jpg" alt="Screenshot 2" />
    <img src="assets/images/03.jpg" alt="Screenshot 3" />
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
      <h3>极简交互</h3>
      <p>专为车内弱交互场景设计的深色 UI 与全方位触觉反馈。让专注回归驾驶本身。</p>
    </div>
  </div>

  <footer style="margin-top: 6rem; padding-bottom: 4rem; border-top: 1px solid #f5f5f7; padding-top: 2rem;">
    <p style="font-size: 0.8rem; color: #86868b;">
      基于 GPL-3.0 开源 · 隐私第一 · 所有数据本地存储<br>
      © 2024 Puked Team.
    </p>
  </footer>
</div>
