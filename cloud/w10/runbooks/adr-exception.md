# Architecture Decision Record (ADR): Xử lý ngoại lệ lỗ hổng bảo mật (CVE Exception)

* **Trạng thái**: Approved / Active
* **Tác giả**: Team Platform / Security Engineer
* **Ngày quyết định**: 2026-06-18

---

## 1. Bối cảnh (Context)
Trong quy trình xây dựng chuỗi cung ứng phần mềm an toàn (Secure Supply Chain), máy quét lỗ hổng Trivy được tích hợp vào pipeline CI/CD để tự động kiểm tra lỗ hổng bảo mật của Docker Image. Cấu hình mặc định sẽ dừng toàn bộ quy trình build push (fail pipeline) khi phát hiện lỗi bảo mật mức độ nghiêm trọng `HIGH` hoặc `CRITICAL`.

Tuy nhiên, trong thực tế vận hành, xảy ra các trường hợp:
1. **Lỗ hổng chưa có bản vá (Unfixed CVEs)**: Lỗ hổng được công bố công khai nhưng nhà sản xuất (vendor) của thư viện/hệ điều hành nền chưa phát hành bản vá sửa lỗi.
2. **Lỗi không ảnh hưởng trực tiếp (False Positives)**: Thư viện chứa mã lỗi nhưng ứng dụng hoàn toàn không sử dụng hoặc không gọi đến tính năng bị lỗi đó.

Nếu chặn cứng pipeline vô thời hạn trong các trường hợp trên, tiến trình bàn giao sản phẩm (Time-to-Market) của doanh nghiệp sẽ bị đình trệ nghiêm trọng do các yếu tố ngoài tầm kiểm soát của đội phát triển.

---

## 2. Quyết định (Decision)
Chúng tôi quyết định áp dụng chính sách xử lý ngoại lệ (Exception Policy) đối với việc quét CVE như sau:

### A. Tự động bỏ qua lỗi chưa có bản vá sửa lỗi (Unfixed CVEs)
Trong cấu hình quét của Trivy ở pipeline, sử dụng tham số `ignore-unfixed: true`. Quyết định này giúp tránh việc chặn phát triển đối với các lỗi mà đội ngũ kỹ sư của chúng ta không thể tự sửa chữa do nhà sản xuất chưa phát hành bản vá.

### B. Cơ chế xin phê duyệt ngoại lệ (Exception ADR) qua `.trivyignore`
Đối với các CVE đã có bản vá nhưng đội phát triển chưa thể nâng cấp ngay lập tức (ví dụ: nâng cấp thư viện gây ra xung đột phiên bản lớn, cần thời gian refactor code):
1. Đội phát triển khai báo mã CVE cần bỏ qua vào file `.trivyignore` ở thư mục gốc của source code.
2. Mỗi dòng cấu hình trong `.trivyignore` bắt buộc phải đi kèm comment ghi rõ:
   - Lý do xin ngoại lệ (Risk mitigation plan).
   - Thời hạn ngoại lệ (Tối đa là **30 ngày**).
   - Người phê duyệt (Security Owner).
3. Ví dụ cấu hình `.trivyignore`:
   ```text
   # CVE-2024-12345: Xung đột phiên bản thư viện DB, sẽ nâng cấp vào Sprint sau.
   # Hạn ngoại lệ: 2026-07-18
   # Phê duyệt bởi: @HuyVLT (Platform Lead)
   CVE-2024-12345
   ```

---

## 3. Hệ quả (Consequences)

### Tích cực:
* Pipeline CI/CD duy trì được sự linh hoạt, không bị gián đoạn phát triển bởi các lỗi bảo mật vượt ngoài tầm kiểm soát trực tiếp.
* Quy trình xin ngoại lệ được ghi nhận tường minh (Auditable) thông qua lịch sử Git của file `.trivyignore`.

### Tiêu cực / Rủi ro cần giảm thiểu:
* **Tích tụ nợ kỹ thuật bảo mật**: Các ngoại lệ có thể bị bỏ quên nếu không được kiểm soát. 
* **Giải pháp khắc phục**: Thiết lập lịch quét định kỳ hàng tuần (Weekly Security Scan) độc lập với pipeline CI/CD để phát hiện và cảnh báo các ngoại lệ sắp hết hạn hoặc các lỗ hổng mới có bản vá vừa phát hành.
