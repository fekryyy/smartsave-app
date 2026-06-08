# SmartSave - Personal Finance & Savings Application

A cross-platform mobile application for tracking expenses, analyzing spending habits, and achieving savings goals.

## Tech Stack

- **Frontend:** Flutter (Dart) - Clean Architecture, MVVM, Provider
- **Backend:** Node.js + Express (REST API)
- **Database:** MongoDB (Mongoose ODM)
- **Authentication:** JWT + bcrypt, Google OAuth
- **Charts:** fl_chart, Syncfusion
- **Notifications:** Firebase Cloud Messaging, flutter_local_notificationsss

## Project Structure

```
SmartSave/
├── backend/                    # Node.js + Express REST API
│   ├── src/
│   │   ├── config/            # Database config, environment
│   │   ├── controllers/       # Route handlers (10 controllers)
│   │   ├── middleware/         # Auth, validation, error handling
│   │   ├── models/            # Mongoose schemas (6 models)
│   │   ├── routes/            # Express routes (10 route files)
│   │   ├── services/          # Recurring, notifications, AI recommendations
│   │   ├── utils/             # Helpers, logger, email
│   │   └── server.js          # Entry point
│   ├── uploads/               # Receipt uploads
│   └── package.json
├── frontend/smartsave/        # Flutter mobile app
│   ├── lib/
│   │   ├── app/               # App entry, routes
│   │   ├── core/              # Constants, theme, network, errors
│   │   ├── data/              # Models, repositories, datasources
│   │   ├── domain/            # Abstract repositories, use cases
│   │   ├── presentation/      # Providers (6), Screens (13+), Widgets
│   │   └── services/          # Sync, notifications, export
│   └── pubspec.yaml
└── README.md
```

## Features

### 1. Authentication
- Email/password registration and login
- Google Sign-In integration
- Forgot password with email reset
- JWT token-based auth with refresh tokens

### 2. Dashboard
- Current balance, monthly income/expenses
- Savings amount, budget remaining
- Recent transactions list
- Quick action buttons

### 3. Expense & Income Tracking
- CRUD operations for transactions
- 9 expense categories + 6 income sources
- Multiple payment methods
- Date selection, descriptions, tags

### 4. Budget Management
- Monthly overall budget
- Per-category budgets (Food, Transport, etc.)
- Real-time progress tracking with percentage bars
- Budget warnings at 75%, 90%, 100%

### 5. Savings Goals
- Create goals with target amounts and dates
- Monthly contribution tracking
- Visual progress indicators
- Estimated completion date calculation
- Contribution management

### 6. Analytics & Reports
- Pie chart by spending category
- Monthly income vs expenses trend (line chart)
- Savings growth (bar chart)
- Period filters: daily, weekly, monthly, yearly
- Full financial report

### 7. Smart Saving Assistant
- AI-based spending pattern analysis
- Month-over-month category comparison
- Budget overspending alerts
- Savings opportunity detection
- Goal acceleration suggestions
- Personalized financial insights

### 8. Notifications
- Push notifications for budget warnings
- Goal reminders and weekly summaries
- Saving suggestions
- Unread notification badge

### 9. Data Export
- PDF report generation
- Excel (XLSX) with multiple sheets
- CSV export for transactions and goals

### 10. Security
- JWT authentication with refresh tokens
- Password hashing with bcrypt (12 rounds)
- Input validation & sanitization
- Rate limiting on auth endpoints
- Helmet security headers
- CORS configuration

### 11. Additional Features
- **OCR Receipt Scanner** - Extract amounts from receipt photos
- **Recurring Transactions** - Auto-create rent, salary, bills
- **Multi-Currency** - USD, EUR, GBP, EGP, SAR, AED
- **Offline Mode** - Local SQLite caching, sync queue
- **Dark/Light Mode** - Material Design 3 theming

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login |
| POST | `/api/auth/google` | Google Sign-In |
| POST | `/api/auth/forgot-password` | Send reset email |
| POST | `/api/auth/reset-password` | Reset password |
| POST | `/api/auth/refresh-token` | Refresh JWT |
| GET | `/api/auth/profile` | Get user profile |
| PUT | `/api/auth/profile` | Update profile |
| PUT | `/api/auth/change-password` | Change password |
| GET/POST/PUT/DELETE | `/api/transactions` | Transaction CRUD |
| GET/POST/PUT/DELETE | `/api/budgets` | Budget management |
| GET/POST/PUT/DELETE | `/api/goals` | Goal management |
| POST | `/api/goals/:id/contribute` | Add goal contribution |
| GET | `/api/analytics/dashboard` | Dashboard data |
| GET | `/api/analytics/category-breakdown` | Category spending |
| GET | `/api/analytics/monthly-trend` | Monthly trends |
| GET | `/api/analytics/income-vs-expenses` | Income vs expenses |
| GET | `/api/analytics/savings-growth` | Savings growth |
| GET | `/api/analytics/report` | Full financial report |
| GET | `/api/recommendations` | Smart saving tips |
| POST | `/api/ocr/scan` | OCR receipt scan |
| GET/PUT/DELETE | `/api/notifications` | Notifications |
| GET | `/api/export/pdf` | Export PDF |
| GET | `/api/export/csv` | Export CSV |
| GET | `/api/export/excel` | Export Excel |

## Installation

### Prerequisites
- Node.js >= 18
- MongoDB >= 6.0 (local or Atlas)
- Flutter >= 3.10
- Dart >= 3.0

### Backend Setup

```bash
# 1. Navigate to backend
cd SmartSave/backend

# 2. Install dependencies
npm install

# 3. Configure environment
cp .env.example .env
# Edit .env with your MongoDB URI, JWT secret, email config

# 4. Start MongoDB (if local)
mongod

# 5. Run server
npm run dev    # Development with nodemon
# OR
npm start      # Production
```

### Flutter Frontend Setup

```bash
# 1. Navigate to Flutter project
cd SmartSave/frontend/smartsave

# 2. Get dependencies
flutter pub get

# 3. Generate code (if using build_runner)
flutter pub run build_runner build

# 4. Run on device/emulator
flutter run

# 5. Build release
flutter build apk          # Android
flutter build ios          # iOS (requires Mac)
```

### Environment Variables (.env)

```env
PORT=5000
MONGODB_URI=mongodb://localhost:27017/smartsave
JWT_SECRET=your_jwt_secret_key_here
JWT_EXPIRE=30d
JWT_REFRESH_SECRET=your_refresh_secret_here
JWT_REFRESH_EXPIRE=90d
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your_email@gmail.com
EMAIL_PASS=your_app_password
GOOGLE_CLIENT_ID=your_google_client_id
FRONTEND_URL=http://localhost:3000
NODE_ENV=development
```

## Architecture

### Clean Architecture Layers

```
Presentation (Providers/Screens/Widgets)
    ↓
Domain (Repositories Interfaces + Use Cases)
    ↓
Data (Repository Implementations + DataSources)
    ↓
Core (Constants, Network, Theme, Errors)
```

### Design Patterns
- **MVVM** - Model-View-ViewModel with Provider state management
- **Repository Pattern** - Abstract data access layer
- **Dependency Injection** - Via Provider/MultiProvider
- **Singleton** - For API client, database, services
- **Factory** - For model creation from JSON

## Screens

1. **Splash Screen** - Animated logo, auto-navigation
2. **Login Screen** - Email/password, Google Sign-In
3. **Registration Screen** - Create account with validation
4. **Forgot Password Screen** - Email reset flow
5. **Dashboard** - Balance, stats, recent transactions, quick actions
6. **Add Expense** - Amount, category, description, date, payment method
7. **Add Income** - Amount, source, notes, date
8. **Analytics** - Pie charts, line charts, bar charts, recommendations
9. **Savings Goals** - Goal list, progress bars, add/edit/contribute
10. **Budget** - Monthly budgets, category tracking, set budgets
11. **Profile** - User info, stats, menu items, export, logout
12. **Settings** - Dark mode, currency, notifications, password
13. **Notifications** - Budget warnings, goal reminders, summaries
14. **Goal Detail** - Progress circle, details, contributions

## License

MIT License - see LICENSE file
