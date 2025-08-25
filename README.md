# 🚁 Drone Delivery Escrow Smart Contract

A decentralized escrow system for drone deliveries that locks STX tokens until IoT devices confirm successful delivery completion.

## 🌟 Features

- 💰 **Secure Escrow**: Lock STX tokens until delivery confirmation
- 🤖 **IoT Integration**: Automated delivery confirmation via authorized IoT devices
- ⚖️ **Dispute Resolution**: Built-in dispute handling mechanism
- ⏰ **Automatic Timeouts**: Refund system for failed deliveries
- 👨‍💼 **Merchant Verification**: Verified merchant profiles with reputation tracking
- 📊 **Comprehensive Analytics**: Track delivery success rates and device reputation

## 🏗️ Contract Architecture

### Core Components

- **Escrow Management**: Create, confirm, and release escrowed funds
- **IoT Device Registry**: Manage authorized delivery confirmation devices
- **Dispute System**: Handle conflicts between customers and merchants
- **Merchant Profiles**: Track merchant reputation and delivery history

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone this repository
2. Navigate to the project directory
3. Run `clarinet check` to verify the contract

## 📖 Usage Guide

### For Customers 👤

#### Create an Escrow
```clarity
(contract-call? .Drone-Delivery-Escrow create-escrow merchant-address amount "123 Main St, City")
```

#### Release Funds After Delivery
```clarity
(contract-call? .Drone-Delivery-Escrow release-funds escrow-id)
```

#### Request Refund (after timeout)
```clarity
(contract-call? .Drone-Delivery-Escrow request-refund escrow-id)
```

### For Merchants 🏪

#### Register as Merchant
```clarity
(contract-call? .Drone-Delivery-Escrow register-merchant "My Store Name")
```

#### Assign IoT Device to Delivery
```clarity
(contract-call? .Drone-Delivery-Escrow assign-iot-device escrow-id iot-device-address)
```

### For IoT Devices 🔧

#### Confirm Delivery
```clarity
(contract-call? .Drone-Delivery-Escrow confirm-delivery escrow-id confirmation-hash)
```

### For Contract Owner (Admin) ⚙️

#### Register IoT Device
```clarity
(contract-call? .Drone-Delivery-Escrow register-iot-device device-address)
```

#### Verify Merchant
```clarity
(contract-call? .Drone-Delivery-Escrow verify-merchant merchant-address)
```

#### Resolve Dispute
```clarity
(contract-call? .Drone-Delivery-Escrow resolve-dispute escrow-id winner-address)
```

## 📊 Read-Only Functions

### Get Escrow Details
```clarity
(contract-call? .Drone-Delivery-Escrow get-escrow escrow-id)
```

### Check IoT Device Info
```clarity
(contract-call? .Drone-Delivery-Escrow get-iot-device-info device-address)
```

### View Merchant Profile
```clarity
(contract-call? .Drone-Delivery-Escrow get-merchant-profile merchant-address)
```

### Get Contract Statistics
```clarity
(contract-call? .Drone-Delivery-Escrow get-contract-stats)
```

## 🔄 Escrow Lifecycle

1. **Creation** 📝: Customer creates escrow with STX locked
2. **IoT Assignment** 🎯: Merchant assigns authorized IoT device
3. **Delivery** 🚁: Drone completes delivery
4. **Confirmation** ✅: IoT device confirms delivery with hash
5. **Release** 💸: Customer releases funds to merchant

## ⚡ Error Codes

| Code | Description |
|------|-------------|
| u100 | Unauthorized access |
| u101 | Invalid escrow state |
| u102 | Already confirmed |
| u103 | Not found |
| u104 | Insufficient funds |
| u105 | Timeout not reached |
| u106 | Already released |
| u107 | Invalid status |
| u108 | Dispute exists |

## ⏱️ Timeouts

- **Escrow Timeout**: 144 blocks (~24 hours)
- **Dispute Timeout**: 288 blocks (~48 hours)

## 🛡️ Security Features

- ✅ Multi-signature dispute resolution
- ✅ Time-locked refund mechanism
- ✅ IoT device authorization system
- ✅ Merchant verification process
- ✅ Reputation tracking

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity)
- [Clarinet Documentation](https://github.com/hirosystems/clarinet)
