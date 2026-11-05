# permittable-lab: thiết kế

Ngày: 2026-11-05
Gem được kiểm thử: `permittable` (local tại `~/Projects/individual-projects/permittable`, hiện là 0.13.1)

## 1. Mục đích và lý do

Gem permittable đã có bộ test riêng, nhưng tác giả vẫn chưa yên tâm. Bộ test đó dùng controller giả, hoặc gọi thẳng `controller.action(...)` mà không đi qua router. Ngoài ra nó chỉ boot một Rails app tối thiểu để thử Railtie và các rake task. Những phần sau chưa có test trên một app thật:

- request đi qua router và middleware thật
- form do view thật render ra
- engine được mount có controller dùng permittable
- model ActiveRecord thật nhận `permitted_params`
- log thật đã lọc tham số
- rake task chạy trên app sinh ra bằng `rails new`
- tất cả các điểm trên trên nhiều bản Rails

permittable-lab là một app Rails **mô phỏng nghiệp vụ theo dõi đơn hàng**, dựng để kiểm thử **toàn bộ tính năng của gem, cả cũ lẫn mới**. App kiểm tra từng loại trường, các lỗi có thể xảy ra và hành vi mong đợi trong bối cảnh thực tế. App dùng được theo hai cách:

1. **Một lệnh test**, chạy tự động trên Rails 7.2, 8.0 và 8.1.
2. **Mở trình duyệt để thử tay**: dùng app như người dùng thật và xem permittable xử lý request qua bảng Inspector.

Thành công nghĩa là: khi gem có bản mới hoặc tính năng mới, tác giả chạy lab và tin được kết quả. Xanh nghĩa là gem chạy đúng như README mô tả trong một app thật, trên cả ba bản Rails.

## 2. Mục tiêu, ngoài phạm vi, điều không được xảy ra

**Mục tiêu**
- Mỗi tính năng trong README có ít nhất một ca đúng và các ca sai tiêu biểu, chạy qua router thật.
- Form thật (render từ view) được điền bằng trình duyệt headless trong system spec.
- Chạy trên Rails 7.2, 8.0, 8.1. Mỗi bản là một app riêng và có container Docker riêng.
- Đổi được nguồn gem: mặc định dùng **bản local**, có thể chuyển sang bản trên RubyGems.
- Có Inspector trên trình duyệt để xem request đi qua permittable thế nào.

**Ngoài phạm vi** (chưa làm ở bản đầu)
- CI (GitHub Actions). Bản đầu chạy ở máy tác giả qua Docker. *(Đây là lựa chọn của mình; tác giả chưa nói về CI.)*
- Rails dưới 7.2 và API-only app riêng (phần API nằm trong app thường qua `ActionController::API`/Metal).
- Đăng nhập, phân quyền, giao diện đẹp và deploy production.
- Sửa code của gem. Lab chỉ phát hiện lỗi, việc sửa diễn ra ở repo gem.

**Điều không được xảy ra** (dù test vẫn xanh thì cũng tính là thất bại)
- Sửa kết quả mong đợi cho khớp với hành vi hiện tại của gem. **README là nguồn sự thật**: gem làm khác README thì test phải đỏ.
- Có danh sách "lỗi đã biết", `pending`/`skip` hay bất kỳ cơ chế nào giữ test xanh trong khi gem sai. *(Tác giả đã chốt: "test báo đỏ ngay".)*
- Test không thực sự đi qua thứ nó nói là đang kiểm tra. Ví dụ: system spec gửi payload tự dựng thay vì để form thật render và submit.
- Một bản Rails âm thầm bị bỏ qua khi chạy ma trận.
- Khi README mơ hồ, builder không được tự đoán rồi viết kết quả mong đợi. Hãy ghi lại câu hỏi và hỏi tác giả.

## 3. Những gì tác giả đã quyết định

- **Nghiệp vụ:** theo dõi đơn hàng.
- **Phiên bản Rails:** 7.2, 8.0, 8.1.
- **Bố cục:** mỗi bản Rails có **một thư mục app riêng**, tạo bằng `rails new` của đúng bản đó, và **chạy trên Docker**.
- **Code nghiệp vụ dùng chung:** controller, contract, model, view, migration, route, locale và spec viết một lần, cả ba app cùng nạp.
- **Nguồn gem:** chuyển qua lại được, **mặc định dùng bản local**.
- **Cách thử trên trình duyệt:** dùng app như người dùng thật, **có bảng Inspector bên cạnh** (phương án A trong mockup).
- **Gem sai so với README thì test báo đỏ ngay.**
- **Ghim bản cũ trên RubyGems:** mỗi spec được gắn nhãn phiên bản gem mà tính năng của nó ra đời (ví dụ `since: "0.13.0"`). Khi ghim một bản cũ hơn, các spec có nhãn mới hơn không chạy, nhưng báo cáo **phải ghi rõ** "N ca không áp dụng cho bản X" kèm danh sách. Nhãn này chỉ được dựa theo bản ghim, không bao giờ dùng để bỏ qua một ca đang đỏ. Với bản local thì mọi spec đều chạy.
- **Ghim bản gem quá cũ so với DSL mà code dùng chung cần:** app không boot được thì `bin/matrix` báo bản đó đỏ hoặc "không chạy được". Như vậy là chấp nhận được.
- **Database:** dùng PostgreSQL, chạy như một service trong Compose, để thử được các quy tắc riêng cho cột mảng của PG. *(Tác giả chọn thêm PostgreSQL. Việc dùng nó làm DB duy nhất, bỏ SQLite, là lựa chọn của mình.)*
- **Hai chỗ README chưa rõ, tác giả đã trả lời:** trường `nullable:` có `normalize: :squish` nhận `"   "` cho ra `nil`. Mảng scalar chỉ nhận `[""]` cho ra `[]`.
- **Inspector** hiện raw params nguyên văn, kể cả trường `sensitive`, vì nó chỉ chạy ở dev/test.
- **Engine:** có **cả hai** loại. Một engine nằm trong app (trong `Rails.root`) và một engine cài như gem (ngoài `Rails.root`), để thử cả hành vi mặc định lẫn `audit_ignore_outside_root`.

## 4. Bố cục repo (đề xuất của mình)

```
permittable-lab/
  shared/                 # code nghiệp vụ dùng chung, viết một lần
    app/                  # controllers, models, views, contracts, field groups, inspector
    config/               # routes, locales (vi, en), initializer permittable
    db/                   # migrations, seeds
    engines/shipping/     # engine "trong app": phải xuất hiện bên trong Rails.root của mỗi app
    spec/                 # toàn bộ spec
  gems/
    carrier_gateway/      # engine đóng gói như gem (path gem), nằm ngoài Rails.root
  apps/
    rails-7_2/            # rails new của 7.2, mỏng, chỉ nạp shared/
    rails-8_0/
    rails-8_1/
  docker/                 # Dockerfile(s)
  compose.yml
  bin/test                # chạy spec trên một bản Rails (mặc định 8.1)
  bin/matrix              # chạy cả ba bản, in bảng kết quả, exit != 0 nếu có bản đỏ
```

**Ràng buộc khi nạp `shared/`:** code dùng chung phải hoạt động **như code của chính app**: Zeitwerk autoload/eager_load, view paths, locale, migration và route. Không được đóng gói `shared/` thành engine, vì như vậy mọi thứ sẽ chạy trong ngữ cảnh engine và lẫn với phần kiểm thử engine. **Code trong `shared/` (kể cả `engines/shipping`) phải nằm bên trong `Rails.root` của từng app khi chạy** (ví dụ symlink hoặc bind mount). Nếu không, audit/generate/OpenAPI sẽ coi nó là "ngoài app root" và làm sai kết quả mong đợi. Cách nối cụ thể do builder chọn. *(Ràng buộc này là lựa chọn của mình.)*

Mỗi app vẫn giữ những gì `rails new` của bản đó sinh ra, như `config.load_defaults` và các file mặc định, để giống app thật của bản đó nhất có thể.

## 5. Docker và nguồn gem

- `compose.yml` có một service cho mỗi bản Rails. Cổng gợi ý: 7.2 dùng `3072`, 8.0 dùng `3080`, 8.1 dùng `3081`. `docker compose up` sẽ mở cả ba app để thử trên trình duyệt.
- Gem local được mount vào container (đường dẫn host lấy từ `PERMITTABLE_PATH`, mặc định `~/Projects/individual-projects/permittable`). Sửa gem xong chạy lại test là thấy ngay, không cần build gem.
- `PERMITTABLE_SOURCE=local` (mặc định) hoặc `rubygems`. Với `rubygems` có thể kèm `PERMITTABLE_VERSION` để ghim bản. Lab phải in rõ đang dùng nguồn nào và bản nào, cả ở đầu output test lẫn trên thanh điều hướng của app.
- Builder tự xử lý việc lockfile khác nhau giữa hai nguồn gem, sao cho đổi nguồn không làm bẩn git.
- Phiên bản Ruby trong image do builder chọn, miễn hợp với cả ba bản Rails và yêu cầu `>= 3.2` của gem.
- System spec cần trình duyệt headless chạy được trong Docker. Builder chọn Cuprite hoặc Selenium và chọn cách đóng gói Chrome.

## 6. Nghiệp vụ và tính năng gem được thử ở đâu

Model ActiveRecord thật: `Customer`, `Order`, `OrderItem`, `TrackingEvent`, cùng các bảng engine cần.

| Màn hình / endpoint | Tính năng permittable được thử |
|---|---|
| **Tạo đơn** (form HTML, `POST /orders`) | `root:`, `model: Order` (chặn lệch schema), nested (`customer`, `shipping_address`), mảng qua `fields_for` (`items_attributes[0][...]`), `integer` có `in:` khoảng, `decimal`, `date_select` (`(1i)(2i)(3i)`), `time_select`/`datetime_select`, `collection_check_boxes` (mảng scalar có `""` ẩn), `normalize: :email`, `format: :email`, `sensitive:` (số điện thoại), `nullable:` (ghi chú), `format:` regex (mã giảm giá), `length:`, `default:`, `unknown: :error` (kể cả miễn trừ `commit`/CSRF/`button_tag`), một field group dùng lại qua `Permittable.fields` + `use`. Controller dùng `render_error` tùy biến để render lại form với status 422, đúng cách app Turbo thật làm. |
| **Sửa đơn / đổi trạng thái** (`PATCH /orders/:id`) | Cập nhật một phần (vắng mặt so với giá trị mặc định), `in:` cho trạng thái, `finalize` + `violate!` cho ràng buộc giữa nhiều trường, `use G, optional: true`, path param `:id` do router điền. |
| **Webhook của hãng vận chuyển** (`POST /api/carriers/:carrier/tracking_events`, JSON, `ActionController::API`) | JSON body và ParamsWrapper, `datetime` có múi giờ, `:json` có `max_depth:`, `boolean`, `float`, `in:` là registry sống, `validate:`, `transform:`, `virtual:`, lỗi dạng `problem+json`, path param `:carrier`. |
| **Tra mã vận đơn** (`GET /track/:code`, controller `ActionController::Metal`) | Hỗ trợ Metal, gồm cả audit và OpenAPI. |
| **Engine "Shipping"** (trong app, mount tại `/shipping`) | Controller trong engine dùng permittable khi chạy thật. Audit/OpenAPI/generate coi engine này là code của app. |
| **Engine "CarrierGateway"** (dạng gem, mount tại `/gateway`) | Controller trong engine dùng permittable khi chạy thật. Mặc định audit chỉ liệt kê nó ở mục "Ignored as outside the app root". Khi `audit_ignore_outside_root = false` thì nó được audit/xuất ra như bình thường. |
| **Import CSV** (form upload) | `Permittable::Contract.define`, `#call`, `#call!`, `#json_schema`, lỗi theo từng dòng. |
| **Endpoint legacy** | Chế độ monitor (`mode: :monitor` và `PERMITTABLE_MODE=monitor`), `unknown: :log`/`:ignore`, một controller còn dùng `params.require.permit` để `rake permittable:generate` có cái mà soạn nháp. |
| **Toàn app** | Railtie (`filter_parameters`, `filter_attributes`), i18n thông báo lỗi tiếng Việt và tiếng Anh, đổi locale theo request bằng `prepend_around_action`, `message:` dạng String và Hash, event `invalid_parameters.permittable`, các cấu hình `Permittable.mode`/`error_format`/`problem_base_uri`/`check_column_types`/`audit_ignore`/`audit_ignore_outside_root`, `rescue_from` bắt mọi lỗi đặt sau `include`. |

Bảng trên là điểm bắt đầu, **chưa phải danh sách cuối**. Việc đầu tiên của builder là lập **ma trận phủ tính năng** từ README và CHANGELOG của gem, gồm mỗi option, mỗi kiểu dữ liệu, mỗi mã lỗi, mỗi cấu hình, mỗi rake task và mỗi mục trong 0.11–0.13.1. Mỗi dòng trong ma trận trỏ tới spec kiểm tra nó, và lab phải đạt 100% dòng có spec. Ma trận để trong repo và được cập nhật cùng spec, để khi gem có tính năng mới thì thấy ngay chỗ còn thiếu.

**Phần không cần controller** cũng nằm trong ma trận và có spec riêng: `Permittable::Audit.entries` không qua Rails, `Permittable::Generator`, việc thay `filter_parameter_registry`, và alias `ConcernsOnRails` (thêm gem phụ chỉ cho phần này). *(Lựa chọn của mình.)*

**Cấu hình toàn cục** (`error_format`, `mode`): README chỉ cho đặt toàn cục. *(Lựa chọn của mình:)*
- Trong spec, đổi cấu hình quanh từng nhóm ca và trả lại giá trị cũ sau đó.
- Trên trình duyệt, thanh điều hướng (chỉ có ở development) có công tắc `error_format` (envelope/problem) và `mode` (enforce/monitor). Inspector luôn hiện cấu hình đang dùng.
- Không tự viết code render problem+json thay cho đường mặc định của gem. Thứ nhìn thấy phải là đường xử lý thật của gem.
- `render_error` tùy biến chỉ dùng ở form HTML, đúng như README mô tả cho trường hợp đó.

## 7. Bộ test

- **RSpec**, nằm trong `shared/spec/`. Cả ba app chạy cùng một bộ spec.
- **Request spec** đi qua router và middleware thật cho mọi endpoint, gồm ca đúng và các ca sai cho từng tính năng.
- **System spec** dùng trình duyệt headless. Form do view thật render, điền và submit thật, gồm `date_select`, `fields_for`, checkbox, CSRF, thông báo lỗi i18n và Inspector hiển thị đúng.
- **Spec dùng matchers của gem** (`require "permittable/rspec"`: `permit_param`, `accept_params`, `reject_params`…), để kiểm tra chính matchers.
- **Spec log:** request thật ghi ra log, trường `sensitive` hiện là `[FILTERED]`, cả trong log SQL bind.
- **Spec rake task:** chạy `permittable:audit`, `permittable:audit[strict]`, `permittable:openapi` và `permittable:generate` trên chính app, rồi kiểm tra kết quả theo README: exit code, route được liệt kê, engine và Metal có mặt, path params. Builder chọn cách so sánh: kiểm tra từng thuộc tính hoặc dùng file mẫu (golden file). Dùng golden file thì phải có lệnh cập nhật, và cập nhật chỉ được làm khi README đã đổi.
- **Spec chặn lệch schema:** contract trỏ tới cột không tồn tại phải báo lỗi lúc load class, và `check_column_types` phải bắt sai kiểu. Builder chọn cách cô lập, ví dụ boot app trong subprocess.
- **Kết quả mong đợi theo README.** Mỗi nhóm spec ghi chú mục README mà nó kiểm tra.
- `bin/test [7.2|8.0|8.1]` chạy trong Docker, mặc định là 8.1. `bin/matrix` chạy cả ba bản, in bảng (bản Rails × nguồn và bản gem × số ca xanh/đỏ/không áp dụng) và trả exit code khác 0 nếu có bất kỳ bản nào đỏ hoặc không chạy được.
- **Nhãn phiên bản** (`since:`): xem mục 3. Nếu một spec không có nhãn thì coi như áp dụng cho mọi bản.

**README mơ hồ và tiêu chí "xong"** *(lựa chọn của mình)*:
- Khi README không đủ rõ để viết kết quả mong đợi, dòng đó trong ma trận được ghi **"chờ tác giả"** kèm câu hỏi, và **không tính là đã phủ**. Builder gom các câu hỏi lại hỏi tác giả một lần, rồi viết spec theo câu trả lời.
- Lab được coi là xong khi mọi dòng trong ma trận đã có spec hoặc đang "chờ tác giả", và bộ test chạy được trên cả ba bản Rails.
- Spec đỏ vì gem làm khác README là **phát hiện**, được liệt kê trong báo cáo bàn giao. Đó không phải lý do để dừng hay để sửa kết quả mong đợi.

## 8. Inspector (thử trên trình duyệt)

Phương án A tác giả đã chọn: dùng app như người dùng thật, bên phải là bảng Inspector cho request vừa gửi, gồm:

- HTTP status
- raw params đúng như trình duyệt gửi, kể cả `(1i)`, `[0]` và `""` ẩn
- `permitted_params` sau khi cast, hoặc "bị từ chối"
- danh sách violation (đường dẫn, mã lỗi, thông báo)
- response body (envelope hoặc problem+json)
- dòng log Rails của request, đã lọc tham số
- event `invalid_parameters.permittable` nếu có

Ngoài ra:
- Thanh điều hướng có: Đơn hàng, Tạo đơn, Webhook, Import CSV, Tra mã vận đơn, Shipping (engine), Legacy, chọn locale vi/en, và nhãn bản Rails cùng nguồn/bản gem.
- Với endpoint JSON (webhook), có một trang soạn payload JSON (textarea), gửi đi và xem Inspector.
- Inspector **chỉ bật trong development và test**, không bao giờ bật trong production. Inspector không được làm thay đổi hành vi của permittable mà nó đang quan sát.
- Có `db/seeds` để mở app lên là có sẵn đơn hàng và sự kiện tracking.
- Giao diện chỉ cần gọn và dễ đọc, không cần đẹp.

## 9. Để builder quyết định

- Cách nối `shared/` vào từng app (theo ràng buộc ở mục 4).
- Phiên bản Ruby, cấu trúc Dockerfile, trình duyệt headless.
- Cách xử lý lockfile khi đổi nguồn gem.
- Cách thử các cấu hình toàn cục (theo ràng buộc ở mục 6).
- Golden file hay kiểm tra từng thuộc tính cho rake task.
- Chi tiết schema DB, dữ liệu seed và giao diện.
- Thứ tự xây dựng. Gợi ý: một app (8.1) chạy được với Docker và đúng một luồng (tạo đơn) có cả request spec, system spec và Inspector, rồi mới nhân lên 7.2 và 8.0 và phủ dần các tính năng còn lại.
