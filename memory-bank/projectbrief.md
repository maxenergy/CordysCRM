# σ₁: Project Brief
*v1.0 | Created: 2025-12-12 | Updated: 2025-12-12*
*Π: DEVELOPMENT | Ω: RESEARCH*

## 🏆 Overview
CordysCRM - 企业级 CRM 系统，包含前端(TypeScript)、后端(Java)、移动端(Flutter)

## 📋 Current Task - 爱企查配置保存错误修复
**问题描述**:
- 位置: 集成配置 -> 爱企查配置
- 操作: 保存爱企查 Cookie
- 后端错误: `2025-12-12 18:08:47,769 ERROR cn.cordys.common.util.LogUtils: 189 - Method[error][No static resource]`
- 前端显示: "从消息体中未获取到数据 Cookie"
- 前端控制台: 无错误信息

## 🎯 Requirements
- [R₁] 定位 "No static resource" 错误的根本原因
- [R₂] 修复爱企查 Cookie 保存功能
- [R₃] 确保前后端数据传输正确
- [R₄] 验证修复后功能正常工作

## 📊 Success Criteria
- Cookie 能够成功保存
- 后端不再报 "No static resource" 错误
- 前端能正确显示保存结果

