# 📊 Alarm States — CloudWatch

## Các trạng thái của CloudWatch Alarm

CloudWatch Alarm có **3 trạng thái** chính:

---

### 🟢 OK
- **Ý nghĩa:** Metric đang trong ngưỡng cho phép (CPU ≤ 80%)
- **Action:** Nếu cấu hình `ok_actions`, email recovery sẽ được gửi
- **Màu sắc Console:** Xanh lá

### 🔴 ALARM
- **Ý nghĩa:** Metric vượt ngưỡng đã định (CPU > 80% trong 5 phút)
- **Action:** Trigger `alarm_actions` → Gửi email qua SNS
- **Màu sắc Console:** Đỏ

### ⚫ INSUFFICIENT_DATA
- **Ý nghĩa:** Chưa đủ dữ liệu để đánh giá (thường xảy ra khi mới tạo alarm)
- **Nguyên nhân phổ biến:**
  - EC2 instance vừa khởi động
  - Instance đang stopped (không gửi metrics)
  - Mới tạo alarm, chưa qua 1 period
- **Action:** Không trigger action (theo cấu hình `treat_missing_data: notBreaching`)

---

## Diagram Chuyển Trạng Thái

```
                    CPU ≤ 80%
    ┌───────────────────────────────────────┐
    │                                       │
    ▼                                       │
  ┌─────┐     CPU > 80% (5 phút)     ┌───────┐
  │ OK  │ ─────────────────────────► │ ALARM │
  └─────┘                             └───────┘
    ▲                                       │
    │                                       │
    └───────────────────────────────────────┘
                    CPU ≤ 80%

  ┌──────────────────────┐
  │  INSUFFICIENT_DATA   │ ──► OK hoặc ALARM (sau khi có đủ dữ liệu)
  └──────────────────────┘
```

---

## Evaluation Period & Datapoints Explained

**Cấu hình lab này:**
```
Period: 300s (5 phút)
Evaluation Periods: 1
Datapoints to alarm: 1 out of 1
```

**Ý nghĩa:** CloudWatch lấy **trung bình CPU trong 5 phút**. Nếu **1 datapoint** (= 1 period = 5 phút) có giá trị > 80% → chuyển sang ALARM.

**So sánh với cấu hình nghiêm ngặt hơn:**
```
Period: 60s (1 phút)
Evaluation Periods: 5
Datapoints to alarm: 3 out of 5
```
→ Cần **3 trong 5 phút** có CPU > 80% mới trigger → ít false alarm hơn.

---

## Treat Missing Data

| Giá trị | Hành vi |
|--------|---------|
| `notBreaching` | Coi missing data là OK (không vi phạm ngưỡng) |
| `breaching` | Coi missing data là ALARM |
| `ignore` | Giữ nguyên trạng thái hiện tại |
| `missing` | Alarm chuyển sang INSUFFICIENT_DATA |

**Lab này dùng `notBreaching`** vì khi EC2 stopped, không có metric là bình thường.
