# GEMINI.md: Cordys CRM Project Guide

This document provides a comprehensive overview of the Cordys CRM project, its architecture, and development workflows.

## 1. Project Overview

Cordys CRM is a full-stack, open-source AI-enhanced Customer Relationship Management system. It features a modular architecture comprising a backend API, a web application, a mobile-responsive web app, and a native mobile (Flutter) application.

### Core Technologies

*   **Backend:**
    *   **Language/Framework:** Java 21 / Spring Boot 3
    *   **Build Tool:** Apache Maven
    *   **Persistence:** MyBatis, Flyway (migrations)
    *   **Database:** MySQL
    *   **Caching/Session:** Redis (via Redisson)
    *   **Security:** Apache Shiro
    *   **API Documentation:** Springdoc (OpenAPI v3)
    *   **Web Server:** Jetty
*   **Frontend (Web & Mobile Web):**
    *   **Framework:** Vue.js 3
    *   **Build Tool:** Vite
    *   **Package Manager:** pnpm (with workspaces)
    *   **UI Frameworks:** Naive UI (for `web`), Vant UI (for `mobile`)
    *   **State Management:** Pinia
    *   **Language:** TypeScript
*   **Native Mobile App:**
    *   **Framework:** Flutter
    *   **State Management:** Riverpod
    *   **Networking:** Dio, Retrofit
    *   **Local Storage:** Drift (SQLite)
    *   **Routing:** go_router

### Directory Structure

*   `backend/`: Contains the Spring Boot application, organized into `framework`, `crm`, and `app` modules.
*   `frontend/`: A pnpm monorepo for all web-based frontends.
    *   `frontend/packages/web/`: The main desktop web application.
    *   `frontend/packages/mobile/`: The responsive web application for mobile browsers.
*   `mobile/cordyscrm_flutter/`: The source code for the native Flutter app (iOS/Android).
*   `installer/`: Docker configurations and startup scripts for deployment.
*   `pom.xml`: The root Maven POM file, orchestrating the backend build and integrating the frontend build.

## 2. Building and Running

The project is designed to be built and run using Docker, but individual components can also be run locally for development.

### Recommended: Docker (Production-like)

The quickest way to run the entire application is to use the pre-built Docker image as described in the `README.md`.

To build the Docker image from source:

1.  **Prerequisites:** Docker, Java 21, Node.js, and `pnpm`.
2.  **Command:** From the project root, run:
    ```bash
    # This command is illustrative based on the installer/Dockerfile
    # and assumes you are building for your current platform.
    docker build -t cordys-crm-local .
    ```
    This process will:
    a. Build the frontend assets using `pnpm`.
    b. Build the backend Java application using `./mvnw`.
    c. Assemble the final Docker image with all necessary components.

### Local Development

#### Backend

1.  **Prerequisites:** Java 21 (JDK), Maven, running instances of MySQL and Redis.
2.  **Configure:** Update the database and Redis connection details, likely in a properties file under `backend/app/src/main/resources/`.
3.  **Build:**
    ```bash
    # From the project root, build the backend without running tests
    ./mvnw clean package -DskipTests
    ```
4.  **Run:** Launch the main application class `cn.cordys.Application` from your IDE or using `java -jar`.

#### Frontend

1.  **Prerequisites:** Node.js, `pnpm`.
2.  **Install Dependencies:**
    ```bash
    # Navigate to the frontend directory and install
    cd frontend
    pnpm install
    ```
3.  **Run a Specific App (e.g., Web):**
    ```bash
    # The exact script name might vary, check packages/web/package.json
    # This is an assumed command.
    pnpm --filter @cordys/web run dev
    ```
    This will start the Vite development server for the web application, typically with hot-reloading. The API server (the backend) must be running separately for the frontend to function.

#### Native Mobile (Flutter)

1.  **Prerequisites:** Flutter SDK, Android Studio/Xcode for emulators/simulators.
2.  **Navigate to Directory:** `cd mobile/cordyscrm_flutter`
3.  **Install Dependencies:** `flutter pub get`
4.  **Run:** Launch the app from your IDE or use `flutter run`.

## 3. Development Conventions

*   **Code Style:** The project enforces code style through `ESLint`, `Prettier`, and `Stylelint` in the frontend. Adhere to the existing configurations.
*   **Git Hooks:** `Husky` is configured to run checks before committing. Ensure you run `pnpm prepare` in the `frontend` directory after cloning to set up the hooks.
*   **Commits:** Conventional Commits are likely used, based on the `commitlint` dependency.
*   **Testing:**
    *   Backend testing relies on JUnit 5, Testcontainers (for integration tests), and JaCoCo (for code coverage).
    *   Frontend testing setup is likely defined within the individual workspace packages.
*   **Contributions:** Follow the guidelines in `CONTRIBUTING.md`. Create issues for significant changes and keep Pull Requests small and focused.
