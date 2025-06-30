# Test API Upload File Miêu Tả Offchain

## API Endpoint
```
POST /offchain/uploadDescriptions
```

## Mô tả
API này dùng để upload file miêu tả (hình ảnh, video) cho sản phẩm và lưu trữ trong CouchDB offchain.

## Parameters

### Form Data:
- `formID`: ID định danh form (bắt buộc)
- `contentType`: Loại nội dung (bắt buộc)
- `descriptions`: File miêu tả (bắt buộc, max 1 file)
- `thumbnail`: File thumbnail cho video (tùy chọn, max 1 file)

### Headers:
- `Authorization`: Bearer JWT token (bắt buộc)

## Test Cases

### 1. Upload hình ảnh đơn giản

```bash
curl -X POST \
  http://localhost:3000/offchain/uploadDescriptions \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -F 'formID=test-form-001' \
  -F 'contentType=image' \
  -F 'descriptions=@/path/to/your/image.jpg'
```

### 2. Upload video với thumbnail

```bash
curl -X POST \
  http://localhost:3000/offchain/uploadDescriptions \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -F 'formID=test-form-002' \
  -F 'contentType=video' \
  -F 'descriptions=@/path/to/your/video.mp4' \
  -F 'thumbnail=@/path/to/your/thumbnail.jpg'
```

### 3. Upload cho sản phẩm thực tế

```bash
curl -X POST \
  http://localhost:3000/offchain/uploadDescriptions \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -F 'formID=22c67116-44fb-4421-947f-a14e91fb21f4' \
  -F 'contentType=image' \
  -F 'descriptions=@/path/to/product_image.jpg'
```

## Response Examples

### Success Response:
```json
{
  "success": true,
  "message": {
    "success": true,
    "message": "Add record to database successfully"
  }
}
```

### Error Response (Missing formID):
```json
{
  "success": false,
  "message": "Missing field"
}
```

### Error Response (Server Error):
```json
{
  "success": false,
  "message": "Error details..."
}
```

## Test với Postman

### 1. Tạo request POST mới
- URL: `http://localhost:3000/offchain/uploadDescriptions`
- Method: `POST`

### 2. Headers
```
Authorization: Bearer YOUR_JWT_TOKEN
```

### 3. Body (form-data)
```
formID: test-form-001
contentType: image
descriptions: [Select File]
thumbnail: [Select File] (optional)
```

## Test với JavaScript/Fetch

```javascript
const formData = new FormData();
formData.append('formID', 'test-form-001');
formData.append('contentType', 'image');

// Thêm file
const fileInput = document.getElementById('fileInput');
formData.append('descriptions', fileInput.files[0]);

// Thêm thumbnail (nếu có)
const thumbnailInput = document.getElementById('thumbnailInput');
if (thumbnailInput.files[0]) {
  formData.append('thumbnail', thumbnailInput.files[0]);
}

fetch('/offchain/uploadDescriptions', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer ' + jwtToken
  },
  body: formData
})
.then(response => response.json())
.then(data => {
  console.log('Success:', data);
})
.catch(error => {
  console.error('Error:', error);
});
```

## Lưu ý quan trọng

1. **File size limit**: 100MB (được cấu hình trong multer)
2. **Supported file types**: Hình ảnh (jpg, png, gif) và video (mp4, avi, mov)
3. **Storage**: Files được lưu trong CouchDB offchain
4. **Hash**: Mỗi file được tạo hash SHA256 để đảm bảo tính toàn vẹn
5. **Path**: Files được lưu tại `images/descriptions/` trong CouchDB

## Kiểm tra file đã upload

Sau khi upload thành công, bạn có thể kiểm tra file bằng cách:

1. **Truy vấn sản phẩm** để xem FormIDMoiNhat
2. **Gọi API read offchain** với FormID để lấy thông tin file
3. **Truy cập file** qua URL: `http://localhost:3000/images/descriptions/filename.ext`

## Troubleshooting

### Lỗi thường gặp:
1. **"Missing field"**: Thiếu formID
2. **"File too large"**: File vượt quá 100MB
3. **"Unauthorized"**: JWT token không hợp lệ
4. **"CouchDB connection error"**: CouchDB không khả dụng

### Debug:
- Kiểm tra logs của backend service
- Kiểm tra CouchDB connection
- Verify JWT token
- Kiểm tra file permissions 