# 📋 Blockchain Attendance Tracker

An immutable attendance tracking system built on the Stacks blockchain using Clarity smart contracts. Perfect for schools, offices, and organizations that need transparent and tamper-proof attendance records! 🎯

## 🚀 Features

- ✅ **User Registration**: Register students/employees with roles
- 🕐 **Check-in/Check-out**: Record attendance with timestamps
- 📊 **Daily Statistics**: Track attendance metrics per day
- 👥 **User Management**: Activate/deactivate users
- 🔒 **Immutable Records**: All attendance data stored permanently on blockchain
- 📈 **Attendance Analytics**: View individual and collective attendance data

## 🛠️ Installation

```bash
git clone <your-repo>
cd attendance-tracker
clarinet check
```

## 📖 Usage

### Register a User
Only contract owner can register new users:

```clarity
(contract-call? .attendance-tracker register-user 'SP1234... "John Doe" "student")
```

### Check In
Users can check in for a specific date:

```clarity
(contract-call? .attendance-tracker check-in u20240101)
```

### Check Out
Users can check out and add optional notes:

```clarity
(contract-call? .attendance-tracker check-out u20240101 (some "Left early for appointment"))
```

### Mark Absent
Contract owner can mark users as absent:

```clarity
(contract-call? .attendance-tracker mark-absent 'SP1234... u20240101 (some "Sick leave"))
```

### View Attendance Record
Check attendance for specific user and date:

```clarity
(contract-call? .attendance-tracker get-attendance-record 'SP1234... u20240101)
```

### Get User Info
View user details and total attendance days:

```clarity
(contract-call? .attendance-tracker get-user-info 'SP1234...)
```

### Daily Statistics
View attendance statistics for any date:

```clarity
(contract-call? .attendance-tracker get-daily-stats u20240101)
```

## 🎯 Core Functions

| Function | Description | Access |
|----------|-------------|---------|
| `register-user` | Register new user with name and role | Owner only |
| `check-in` | Record attendance check-in | Registered users |
| `check-out` | Record attendance check-out with notes | Registered users |
| `mark-absent` | Mark user as absent for specific date | Owner only |
| `deactivate-user` | Deactivate user account | Owner only |
| `reactivate-user` | Reactivate user account | Owner only |

## 📊 Read-Only Functions

- `get-user-info` - Get user details
- `get-attendance-record` - Get specific attendance record
- `get-daily-stats` - Get daily attendance statistics
- `get-user-attendance-count` - Get total attendance days for user
- `is-user-active` - Check if user is active
- `get-total-registered-users` - Get total registered users count

## 🔐 Security Features

- Owner-only administrative functions
- User activation/deactivation controls
- Duplicate check-in prevention
- Input validation for all functions

## 🧪 Testing

```bash
clarinet test
```

## 📝 Date Format

Use numeric date format (YYYYMMDD as uint):
- January 1, 2024 = `u20240101`
- December 31, 2024 = `u20241231`

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

## 📄 License

MIT License - feel free to use for educational and commercial purposes! 🎉
```

**Git Commit Message:**
```
feat: implement blockchain attendance tracker MVP with user management and immutable records
```

**GitHub Pull Request Title:**
```
🚀 Add Blockchain Attendance Tracker MVP
```

**GitHub Pull Request Description:**
```
## 📋 What's Added

This PR introduces a complete MVP for a blockchain-based attendance tracking system built with Clarity smart contracts.

### ✨ Key Features
- **User Registration & Management** - Register students/employees with roles and status control
- **Attendance Recording** - Immutable check-in/check-out functionality with timestamps
- **Daily Statistics** - Automated tracking of daily attendance metrics
- **Administrative Controls** - Owner-only functions for user management and absence marking
- **Comprehensive Read Functions** - Multiple ways to query attendance data and user information

### 🔧 Technical Implementation
- **150+ lines of clean Clarity code** with proper error handling
- **Secure access controls** with owner-only administrative functions
- **Data integrity** with duplicate prevention and input validation
- **Efficient storage** using optimized map structures for users, records, and statistics

### 📚 Documentation
- Complete README with usage examples and API documentation
- Clear function descriptions and security features overview
- Installation and testing instructions

This MVP provides a solid foundation for any organization needing transparent, tamper-proof attendance tracking on the blockchain! 🎯
