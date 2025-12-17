# Requirements Document

## Introduction

本功能为 CordysCRM Flutter 移动应用增加企查查（qcc.com）企业搜索集成，作为爱企查（aiqicha.baidu.com）的替代方案。由于爱企查的反爬虫机制较为严格，经常触发滑块验证，本功能使用企查查作为外部企业信息数据源。

用户可以通过 WebView 访问企查查网站，搜索企业信息，并将企业数据导入到 CRM 系统中。

## Glossary

- **企查查 (QCC)**: 企查查（qcc.com），中国领先的企业信息查询平台
- **WebView**: 应用内嵌浏览器组件，用于加载和显示网页
- **Enterprise**: 企业实体，包含企业名称、统一社会信用代码、法人等信息
- **CRM**: 客户关系管理系统
- **Flutter**: 跨平台移动应用开发框架

## Requirements

### Requirement 1

**User Story:** As a sales representative, I want to search for enterprises on QCC through the mobile app, so that I can find potential customers and import their information into CRM.

#### Acceptance Criteria

1. WHEN a user opens the enterprise search page THEN the system SHALL display a search input field and a button to open QCC WebView
2. WHEN a user taps the QCC button THEN the system SHALL open a WebView page loading https://www.qcc.com
3. WHEN the QCC WebView page loads THEN the system SHALL display a loading progress indicator
4. WHEN the user navigates to an enterprise detail page on QCC THEN the system SHALL inject a floating "Import to CRM" button
5. WHEN the user taps the "Import to CRM" button THEN the system SHALL extract enterprise data from the page DOM

### Requirement 2

**User Story:** As a sales representative, I want to extract enterprise information from QCC detail pages, so that I can import accurate data into CRM.

#### Acceptance Criteria

1. WHEN extracting enterprise data THEN the system SHALL parse the enterprise name from the page
2. WHEN extracting enterprise data THEN the system SHALL parse the unified social credit code (统一社会信用代码) if available
3. WHEN extracting enterprise data THEN the system SHALL parse the legal representative (法定代表人) if available
4. WHEN extracting enterprise data THEN the system SHALL parse the registered capital (注册资本) if available
5. WHEN extracting enterprise data THEN the system SHALL parse the establishment date (成立日期) if available
6. WHEN extracting enterprise data THEN the system SHALL parse the business status (经营状态) if available
7. WHEN extracting enterprise data THEN the system SHALL parse the registered address (注册地址) if available

### Requirement 3

**User Story:** As a sales representative, I want to preview extracted enterprise data before importing, so that I can verify the information is correct.

#### Acceptance Criteria

1. WHEN enterprise data is extracted THEN the system SHALL display a preview bottom sheet with the extracted information
2. WHEN displaying the preview THEN the system SHALL allow the user to edit the enterprise name before importing
3. WHEN the user confirms import THEN the system SHALL call the backend API to create or update the customer record
4. WHEN import succeeds THEN the system SHALL display a success message and close the preview sheet
5. IF import fails due to duplicate THEN the system SHALL display a conflict resolution dialog

### Requirement 4

**User Story:** As a sales representative, I want to receive enterprise links shared from other apps, so that I can quickly import enterprise information.

#### Acceptance Criteria

1. WHEN the app receives a shared URL containing "qcc.com" THEN the system SHALL open the QCC WebView with that URL
2. WHEN the shared URL is an enterprise detail page THEN the system SHALL automatically inject the import button after page load
3. WHEN the user is not logged in to CRM THEN the system SHALL prompt the user to log in first

### Requirement 5

**User Story:** As a system administrator, I want to switch between QCC and Aiqicha data sources, so that I can choose the most reliable source.

#### Acceptance Criteria

1. WHEN configuring enterprise search THEN the system SHALL provide an option to select the external data source (QCC or Aiqicha)
2. WHEN QCC is selected as the data source THEN the system SHALL use QCC WebView for external enterprise search
3. WHEN Aiqicha is selected as the data source THEN the system SHALL use Aiqicha WebView for external enterprise search
4. THE system SHALL default to QCC as the external data source
