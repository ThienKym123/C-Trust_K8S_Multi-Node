package chaincode

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/antzucaro/matchr"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract struct
type SmartContract struct {
	contractapi.Contract
}

// Data struct format
type Data struct {
	ID                 string   `json:"ID"`
	TenSanPham         string   `json:"TenSanPham"`
	NhaSanXuat         string   `json:"NhaSanXuat"`
	ThoiGian           string   `json:"ThoiGian"`
	DiaDiem            string   `json:"DiaDiem"`
	ToaDo              string   `json:"ToaDo"`
	MoTa               string   `json:"MoTa"`
	TrangThai          string   `json:"TrangThai"`
	ThucHien           string   `json:"ThucHien"`
	DanhSachChuyenGiao []string `json:"DanhSachChuyenGiao"`
	ChuyenGiaoMoiNhat  string   `json:"ChuyenGiaoMoiNhat"`
	DanhSachFormID     []string `json:"DanhSachFormID"`
	FormIDMoiNhat      string   `json:"FormIDMoiNhat"`
	MaDongGoiMoiNhat   string   `json:"MaDongGoiMoiNhat"`
	DanhSachMaDongGoi  []string `json:"DanhSachMaDongGoi"`
	HoanThanhDongGoi   bool     `json:"HoanThanhDongGoi"`
	HashValueOffchain  string   `json:"HashValueOffchain"`
	HashValue          string   `json:"HashValue"`
	HashPb             string   `json:"HashPb"`
	SoLuong            int      `json:"SoLuong"`
	DonViDoSoLuong     string   `json:"DonViDoSoLuong"`
	HSD                string   `json:"HSD"`
}

// Document struct
type Document struct {
	Key        string `json:"Key"`
	Value      string `json:"Value"`
	ID         string `json:"ID"`
	NhaSanXuat string `json:"NhaSanXuat"`
}

// TheoDoiDoanhThu struct
type TheoDoiDoanhThu struct {
	TenSanPham        string   `json:"TenSanPham"`
	ID                string   `json:"ID"`
	NhaSanXuat        string   `json:"NhaSanXuat"`
	ThoiGian          string   `json:"ThoiGian"`
	DanhSachMaDongGoi []string `json:"DanhSachMaDongGoi"`
	SoLuong           int      `json:"SoLuong"`
	DonViDoSoLuong    string   `json:"DonViDoSoLuong"`
	HSD               string   `json:"HSD"`
	UUID              string   `json:"UUID"`
}

// DanhSachSanPham struct
type DanhSachSanPham struct {
	Username   string   `json:"Username"`
	SanPhamMoi string   `json:"SanPhamMoi"`
	DanhSach   []string `json:"DanhSach"`
}

// getHashValue struct
type getHashValue struct {
	ID         string `json:"ID"`
	NhaSanXuat string `json:"NhaSanXuat"`
	Index      string `json:"Index"`
}

// DanhSachSanPhamKemPageIndexVaPageSize struct
type DanhSachSanPhamKemPageIndexVaPageSize struct {
	PageIndex string `json:"PageIndex"`
	PageSize  string `json:"PageSize"`
}

// SearchSanPham struct
type SearchSanPham struct {
	Keyword string `json:"Keyword"`
}

var SOURCE_CHARACTERS, LL_LENGTH = stringToRune(`ÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÝàáâãèéêìíòóôõùúýĂăĐđĨĩŨũƠơƯưẠạẢảẤấẦầẨẩẪẫẬậẮắẰằẲẳẴẵẶặẸẹẺẻẼẽẾếỀềỂểỄễỆệỈỉỊịỌọỎỏỐốỒồỔổỖỗỘộỚớỜờỞởỠỡỢợỤụỦủỨứỪừỬửỮữỰự`)
var DESTINATION_CHARACTERS, _ = stringToRune(`AAAAEEEIIOOOOUUYaaaaeeeiioooouuyAaDdIiUuOoUuAaAaAaAaAaAaAaAaAaAaAaAaEeEeEeEeEeEeEeEeIiIiOoOoOoOoOoOoOoOoOoOoOoOoUuUuUuUuUuUuUu`)

// Exist checks if a key exists in the ledger
func Exist(ctx contractapi.TransactionContextInterface, key string) ([]byte, error) {
	exist, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("không thể đọc sổ cái: %s", err)
	}
	return exist, nil
}

// Init initializes the chaincode
func (s *SmartContract) Init(ctx contractapi.TransactionContextInterface) error {
	return nil
}

// getUsernameFromCertificate extracts username from certificate ID
func getUsernameFromCertificate(certID string) string {
	// Certificate ID format: "x509::CN=username,OU=org1+OU=client+OU=department1::CN=fabric-ca-server,OU=Fabric,O=Hyperledger,ST=North Carolina,C=US"
	// Extract username from CN=username part
	if strings.Contains(certID, "CN=") {
		parts := strings.Split(certID, ",")
		for _, part := range parts {
			if strings.HasPrefix(part, "CN=") {
				username := strings.TrimPrefix(part, "CN=")
				// Remove any additional parts after the first CN=
				if strings.Contains(username, ",") {
					username = strings.Split(username, ",")[0]
				}
				return username
			}
		}
	}
	return certID // fallback to original ID if parsing fails
}

// Create creates a new product record
func (s *SmartContract) Create(ctx contractapi.TransactionContextInterface, params string) (string, error) {
	certID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return "", fmt.Errorf("không thể lấy ID người dùng: %s", err)
	}
	owner := getUsernameFromCertificate(certID)

	var data Data
	if err := json.Unmarshal([]byte(params), &data); err != nil {
		return "", fmt.Errorf("lỗi phân tích params: %s", err)
	}

	// Bổ sung các giá trị mặc định
	data.ThucHien = data.NhaSanXuat
	data.ChuyenGiaoMoiNhat = owner
	data.DanhSachChuyenGiao = append(data.DanhSachChuyenGiao, owner)
	data.DanhSachFormID = append(data.DanhSachFormID, data.FormIDMoiNhat)
	data.HashPb = ""
	data.MaDongGoiMoiNhat = ""

	// Tính hash
	hashv := sha256.Sum256([]byte(data.ID + data.TenSanPham + data.NhaSanXuat + data.ThoiGian + data.DiaDiem + data.ToaDo + data.TrangThai + data.MaDongGoiMoiNhat + data.HashPb + data.HashValue))
	data.HashValue = hex.EncodeToString(hashv[:])

	// Key sản phẩm
	keySanPham, err := ctx.GetStub().CreateCompositeKey(data.NhaSanXuat, []string{data.NhaSanXuat, data.ID})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key sản phẩm: %s", err)
	}

	exist, err := Exist(ctx, keySanPham)
	if err != nil {
		return "", err
	}
	if exist != nil {
		return "", fmt.Errorf("bản ghi đã tồn tại")
	}

	// Lưu sản phẩm
	productBytes, err := json.Marshal(data)
	if err != nil {
		return "", fmt.Errorf("lỗi mã hóa JSON sản phẩm: %s", err)
	}
	if err := ctx.GetStub().PutState(keySanPham, productBytes); err != nil {
		return "", fmt.Errorf("không thể tạo bản ghi: %s", err)
	}

	// Cập nhật danh sách sản phẩm
	keyDanhSach, err := ctx.GetStub().CreateCompositeKey(owner, []string{owner, "danhSachSanPham"})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key danh sách: %s", err)
	}

	var danhSachCuaUser DanhSachSanPham
	existDanhSach, err := Exist(ctx, keyDanhSach)
	if err != nil {
		return "", err
	}

	if existDanhSach != nil {
		if err := json.Unmarshal(existDanhSach, &danhSachCuaUser); err != nil {
			return "", fmt.Errorf("lỗi phân tích danh sách: %s", err)
		}
		danhSachCuaUser.SanPhamMoi = keySanPham
		danhSachCuaUser.DanhSach = append(danhSachCuaUser.DanhSach, keySanPham)
	} else {
		danhSachCuaUser = DanhSachSanPham{
			Username:   owner,
			SanPhamMoi: keySanPham,
			DanhSach:   []string{keySanPham},
		}
	}

	listBytes, err := json.Marshal(danhSachCuaUser)
	if err != nil {
		return "", fmt.Errorf("lỗi mã hóa danh sách: %s", err)
	}
	if err := ctx.GetStub().PutState(keyDanhSach, listBytes); err != nil {
		return "", fmt.Errorf("không thể cập nhật danh sách: %s", err)
	}

	return string(productBytes), nil
}

// Update updates an existing product record
func (s *SmartContract) Update(ctx contractapi.TransactionContextInterface, params string) (string, error) {
	certID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return "", fmt.Errorf("không thể lấy ID người dùng: %s", err)
	}
	owner := getUsernameFromCertificate(certID)

	var data Data
	if err := json.Unmarshal([]byte(params), &data); err != nil {
		return "", fmt.Errorf("lỗi phân tích params: %s", err)
	}

	key, err := ctx.GetStub().CreateCompositeKey(data.NhaSanXuat, []string{data.NhaSanXuat, data.ID})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key: %s", err)
	}

	exist, err := Exist(ctx, key)
	if err != nil {
		return "", err
	}
	if exist == nil {
		return "", fmt.Errorf("bản ghi không tồn tại")
	}

	var result Data
	if err := json.Unmarshal(exist, &result); err != nil {
		return "", fmt.Errorf("lỗi phân tích bản ghi: %s", err)
	}

	if owner != result.ChuyenGiaoMoiNhat {
		return "", fmt.Errorf("không có quyền cập nhật bản ghi")
	}
	if result.MaDongGoiMoiNhat != "" {
		return "", fmt.Errorf("sản phẩm đang đóng gói, không thể cập nhật")
	}
	if result.HoanThanhDongGoi {
		return "", fmt.Errorf("sản phẩm đã hoàn thành đóng gói, không thể cập nhật")
	}

	result.ThoiGian = data.ThoiGian
	result.DiaDiem = data.DiaDiem
	result.ToaDo = data.ToaDo
	result.MoTa = data.MoTa
	result.TrangThai = data.TrangThai
	result.ThucHien = data.ThucHien
	result.FormIDMoiNhat = data.FormIDMoiNhat
	result.DanhSachFormID = append(result.DanhSachFormID, data.FormIDMoiNhat)
	result.HashValueOffchain = data.HashValueOffchain
	result.HashPb = result.HashValue

	hashv := sha256.Sum256([]byte(result.ID + result.TenSanPham + result.NhaSanXuat + result.ThoiGian + result.DiaDiem + result.ToaDo + result.TrangThai + result.MaDongGoiMoiNhat + result.HashPb + data.HashValue))
	result.HashValue = hex.EncodeToString(hashv[:])

	asBytes, err := json.Marshal(result)
	if err != nil {
		return "", fmt.Errorf("lỗi mã hóa JSON: %s", err)
	}
	if err := ctx.GetStub().PutState(key, asBytes); err != nil {
		return "", fmt.Errorf("không thể cập nhật bản ghi: %s", err)
	}

	return string(asBytes), nil
}

// DongGoiSanPham packages a product
func (s *SmartContract) DongGoiSanPham(ctx contractapi.TransactionContextInterface, params string) (string, error) {
	certID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return "", fmt.Errorf("không thể lấy ID người dùng: %s", err)
	}
	owner := getUsernameFromCertificate(certID)

	var data Data
	if err := json.Unmarshal([]byte(params), &data); err != nil {
		return "", fmt.Errorf("lỗi phân tích params: %s", err)
	}

	keySanPham, err := ctx.GetStub().CreateCompositeKey(data.NhaSanXuat, []string{data.NhaSanXuat, data.ID})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key sản phẩm: %s", err)
	}

	exist, err := Exist(ctx, keySanPham)
	if err != nil {
		return "", err
	}
	if exist == nil {
		return "", fmt.Errorf("sản phẩm không tồn tại")
	}

	var result Data
	if err := json.Unmarshal(exist, &result); err != nil {
		return "", fmt.Errorf("lỗi phân tích bản ghi: %s", err)
	}

	if owner != result.ChuyenGiaoMoiNhat {
		return "", fmt.Errorf("không có quyền cập nhật bản ghi")
	}
	if result.HoanThanhDongGoi {
		return "", fmt.Errorf("sản phẩm đã hoàn thành đóng gói")
	}

	var keyTonTai strings.Builder
	for _, element := range data.DanhSachMaDongGoi {
		keyMaDongGoi, err := ctx.GetStub().CreateCompositeKey(element, []string{element, "MaDongGoi"})
		if err != nil {
			return "", fmt.Errorf("lỗi tạo key mã đóng gói: %s", err)
		}
		if exist, err := Exist(ctx, keyMaDongGoi); err != nil {
			return "", err
		} else if exist != nil {
			keyTonTai.WriteString(" ")
			keyTonTai.WriteString(keyMaDongGoi)
		}
	}
	if keyTonTai.Len() > 0 {
		return "", fmt.Errorf("mã đóng gói đã tồn tại:%s", keyTonTai.String())
	}

	for _, element := range data.DanhSachMaDongGoi {
		keyMaDongGoi, err := ctx.GetStub().CreateCompositeKey(element, []string{element, "MaDongGoi"})
		if err != nil {
			return "", fmt.Errorf("lỗi tạo key mã đóng gói: %s", err)
		}
		dongGoi := Document{
			Key:        keyMaDongGoi,
			Value:      keySanPham,
			ID:         data.ID,
			NhaSanXuat: data.NhaSanXuat,
		}
		asBytes, err := json.Marshal(dongGoi)
		if err != nil {
			return "", fmt.Errorf("lỗi mã hóa JSON: %s", err)
		}
		if err := ctx.GetStub().PutState(keyMaDongGoi, asBytes); err != nil {
			return "", fmt.Errorf("không thể tạo bản ghi mã đóng gói: %s", err)
		}
	}

	result.MoTa = data.MoTa
	result.ToaDo = data.ToaDo
	result.ThoiGian = data.ThoiGian
	result.DiaDiem = data.DiaDiem
	result.TrangThai = data.TrangThai
	result.ThucHien = data.ThucHien
	result.FormIDMoiNhat = data.FormIDMoiNhat
	result.DanhSachFormID = append(result.DanhSachFormID, data.FormIDMoiNhat)
	result.MaDongGoiMoiNhat = data.DanhSachMaDongGoi[len(data.DanhSachMaDongGoi)-1]
	result.DanhSachMaDongGoi = append(result.DanhSachMaDongGoi, data.DanhSachMaDongGoi...)
	result.HoanThanhDongGoi = data.HoanThanhDongGoi
	result.HashValueOffchain = data.HashValueOffchain
	result.HashPb = result.HashValue
	result.SoLuong = len(result.DanhSachMaDongGoi)
	result.DonViDoSoLuong = data.DonViDoSoLuong
	result.HSD = data.HSD

	var maDongGoiCode strings.Builder
	for _, v := range result.DanhSachMaDongGoi {
		maDongGoiCode.WriteString(v)
	}
	hashv := sha256.Sum256([]byte(result.ID + result.TenSanPham + result.NhaSanXuat + result.ThoiGian + result.DiaDiem + result.ToaDo + result.TrangThai + maDongGoiCode.String() + result.HashPb + data.HashValue))
	result.HashValue = hex.EncodeToString(hashv[:])

	asBytes, err := json.Marshal(result)
	if err != nil {
		return "", fmt.Errorf("lỗi mã hóa JSON: %s", err)
	}
	if err := ctx.GetStub().PutState(keySanPham, asBytes); err != nil {
		return "", fmt.Errorf("không thể cập nhật bản ghi: %s", err)
	}

	if data.HoanThanhDongGoi {
		keyTheoDoiDoanhThu, err := ctx.GetStub().CreateCompositeKey(data.NhaSanXuat, []string{data.NhaSanXuat, data.ID, "TheoDoiDoanhThu"})
		if err != nil {
			return "", fmt.Errorf("lỗi tạo key doanh thu: %s", err)
		}
		theoDoi := TheoDoiDoanhThu{
			TenSanPham:        result.TenSanPham,
			ID:                result.ID,
			NhaSanXuat:        result.NhaSanXuat,
			ThoiGian:          result.ThoiGian,
			DanhSachMaDongGoi: result.DanhSachMaDongGoi,
			SoLuong:           result.SoLuong,
			DonViDoSoLuong:    result.DonViDoSoLuong,
			HSD:               result.HSD,
		}
		asBytesDoanhThu, err := json.Marshal(theoDoi)
		if err != nil {
			return "", fmt.Errorf("lỗi mã hóa JSON doanh thu: %s", err)
		}
		if err := ctx.GetStub().PutState(keyTheoDoiDoanhThu, asBytesDoanhThu); err != nil {
			return "", fmt.Errorf("không thể tạo bản ghi doanh thu: %s", err)
		}
	}

	return string(asBytes), nil
}

// Transfer transfers product ownership
func (s *SmartContract) Transfer(ctx contractapi.TransactionContextInterface, params string, name string) error {
	certID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return fmt.Errorf("không thể lấy ID người dùng: %s", err)
	}
	owner := getUsernameFromCertificate(certID)

	var data Data
	if err := json.Unmarshal([]byte(params), &data); err != nil {
		return fmt.Errorf("lỗi phân tích params: %s", err)
	}

	keySanPham, err := ctx.GetStub().CreateCompositeKey(data.NhaSanXuat, []string{data.NhaSanXuat, data.ID})
	if err != nil {
		return fmt.Errorf("lỗi tạo key sản phẩm: %s", err)
	}

	queryResult, err := ctx.GetStub().GetState(keySanPham)
	if err != nil {
		return fmt.Errorf("lỗi truy vấn: %s", err)
	}
	if queryResult == nil {
		return fmt.Errorf("sản phẩm %s không tồn tại", keySanPham)
	}

	var result Data
	if err := json.Unmarshal(queryResult, &result); err != nil {
		return fmt.Errorf("lỗi phân tích bản ghi: %s", err)
	}

	if result.DanhSachChuyenGiao[len(result.DanhSachChuyenGiao)-1] != data.ThucHien {
		return fmt.Errorf("không có quyền chuyển giao")
	}
	if result.HoanThanhDongGoi {
		return fmt.Errorf("sản phẩm đã hoàn thành đóng gói, không thể chuyển giao")
	}
	if result.MaDongGoiMoiNhat != "" {
		return fmt.Errorf("sản phẩm đang đóng gói, không thể chuyển giao")
	}

	result.DiaDiem = data.DiaDiem
	result.ThoiGian = data.ThoiGian
	result.ToaDo = data.ToaDo
	result.MoTa = "Chuyển giao cho " + name
	result.TrangThai = "CHUYỂN GIAO"
	result.ThucHien = name
	result.ChuyenGiaoMoiNhat = owner
	result.DanhSachChuyenGiao = append(result.DanhSachChuyenGiao, owner)
	result.FormIDMoiNhat = data.FormIDMoiNhat
	result.DanhSachFormID = append(result.DanhSachFormID, data.FormIDMoiNhat)
	result.HashValueOffchain = data.HashValueOffchain
	result.HashPb = result.HashValue

	hashv := sha256.Sum256([]byte(result.ID + result.TenSanPham + result.NhaSanXuat + result.ThoiGian + result.DiaDiem + result.ToaDo + result.TrangThai + result.MaDongGoiMoiNhat + result.HashPb + data.HashValue))
	result.HashValue = hex.EncodeToString(hashv[:])

	asBytes, err := json.Marshal(result)
	if err != nil {
		return fmt.Errorf("lỗi mã hóa JSON: %s", err)
	}
	if err := ctx.GetStub().PutState(keySanPham, asBytes); err != nil {
		return fmt.Errorf("không thể cập nhật bản ghi: %s", err)
	}

	keyDanhSach, err := ctx.GetStub().CreateCompositeKey(owner, []string{owner, "danhSachSanPham"})
	if err != nil {
		return fmt.Errorf("lỗi tạo key danh sách: %s", err)
	}

	existDanhSach, err := Exist(ctx, keyDanhSach)
	if err != nil {
		return err
	}

	var danhSachCuaUser DanhSachSanPham
	if existDanhSach != nil {
		if err := json.Unmarshal(existDanhSach, &danhSachCuaUser); err != nil {
			return fmt.Errorf("lỗi phân tích danh sách: %s", err)
		}
		danhSachCuaUser.SanPhamMoi = keySanPham
		exists := false
		for _, a := range danhSachCuaUser.DanhSach {
			if a == keySanPham {
				exists = true
				break
			}
		}
		if !exists {
			danhSachCuaUser.DanhSach = append(danhSachCuaUser.DanhSach, keySanPham)
		}
	} else {
		danhSachCuaUser = DanhSachSanPham{
			Username:   owner,
			SanPhamMoi: keySanPham,
			DanhSach:   []string{keySanPham},
		}
	}

	asBytes, err = json.Marshal(danhSachCuaUser)
	if err != nil {
		return fmt.Errorf("lỗi mã hóa danh sách: %s", err)
	}
	if err := ctx.GetStub().PutState(keyDanhSach, asBytes); err != nil {
		return fmt.Errorf("không thể cập nhật danh sách: %s", err)
	}

	return nil
}

// ThanhToanSanPham processes product payment
func (s *SmartContract) ThanhToanSanPham(ctx contractapi.TransactionContextInterface, params string, uuid string) error {
	var data []TheoDoiDoanhThu
	if err := json.Unmarshal([]byte(params), &data); err != nil {
		return fmt.Errorf("lỗi phân tích params: %s", err)
	}

	var keyTonTai strings.Builder
	for _, element := range data {
		keyMaDoanhThu, err := ctx.GetStub().CreateCompositeKey(element.NhaSanXuat, []string{element.NhaSanXuat, element.ID, "TheoDoiDoanhThu"})
		if err != nil {
			return fmt.Errorf("lỗi tạo key doanh thu: %s", err)
		}
		exist, err := Exist(ctx, keyMaDoanhThu)
		if err != nil {
			return fmt.Errorf("lỗi kiểm tra tồn tại: %s", err)
		}
		if exist == nil {
			keyTonTai.WriteString(" ")
			keyTonTai.WriteString(keyMaDoanhThu)
		} else {
			var result TheoDoiDoanhThu
			if err := json.Unmarshal(exist, &result); err != nil {
				return fmt.Errorf("lỗi phân tích bản ghi: %s", err)
			}
			if result.SoLuong-element.SoLuong < 0 {
				return fmt.Errorf("có hàng giả trong lô hàng: %s", keyMaDoanhThu)
			}
		}
	}
	if keyTonTai.Len() > 0 {
		return fmt.Errorf("sản phẩm không tồn tại:%s", keyTonTai.String())
	}

	for _, element := range data {
		keyMaDoanhThu, err := ctx.GetStub().CreateCompositeKey(element.NhaSanXuat, []string{element.NhaSanXuat, element.ID, "TheoDoiDoanhThu"})
		if err != nil {
			return fmt.Errorf("lỗi tạo key doanh thu: %s", err)
		}
		exist, err := Exist(ctx, keyMaDoanhThu)
		if err != nil {
			return fmt.Errorf("lỗi kiểm tra tồn tại: %s", err)
		}
		if exist == nil {
			return fmt.Errorf("bản ghi doanh thu không tồn tại")
		}

		var result TheoDoiDoanhThu
		if err := json.Unmarshal(exist, &result); err != nil {
			return fmt.Errorf("lỗi phân tích bản ghi: %s", err)
		}
		if result.SoLuong-element.SoLuong < 0 {
			return fmt.Errorf("có hàng giả trong lô hàng")
		}

		result.SoLuong -= element.SoLuong
		result.UUID = uuid
		asBytes, err := json.Marshal(result)
		if err != nil {
			return fmt.Errorf("lỗi mã hóa JSON: %s", err)
		}
		if err := ctx.GetStub().PutState(keyMaDoanhThu, asBytes); err != nil {
			return fmt.Errorf("không thể cập nhật bản ghi doanh thu: %s", err)
		}
	}

	return nil
}

// QueryDoanhThuSanPham queries product revenue
func (s *SmartContract) QueryDoanhThuSanPham(ctx contractapi.TransactionContextInterface, params string) (string, error) {
	var data Document
	if err := json.Unmarshal([]byte(params), &data); err != nil {
		return "", fmt.Errorf("lỗi phân tích params: %s", err)
	}

	keyMaDongGoi, err := ctx.GetStub().CreateCompositeKey(data.Key, []string{data.Key, "MaDongGoi"})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key mã đóng gói: %s", err)
	}

	maDongGoiResult, err := ctx.GetStub().GetState(keyMaDongGoi)
	if err != nil {
		return "", fmt.Errorf("lỗi truy vấn mã đóng gói: %s", err)
	}
	if maDongGoiResult == nil {
		return "", fmt.Errorf("mã đóng gói không tồn tại")
	}

	var result Document
	if err := json.Unmarshal(maDongGoiResult, &result); err != nil {
		return "", fmt.Errorf("lỗi phân tích bản ghi mã đóng gói: %s", err)
	}

	keyDoanhThu, err := ctx.GetStub().CreateCompositeKey(result.NhaSanXuat, []string{result.NhaSanXuat, result.ID, "TheoDoiDoanhThu"})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key doanh thu: %s", err)
	}

	doanhThuResult, err := ctx.GetStub().GetState(keyDoanhThu)
	if err != nil {
		return "", fmt.Errorf("lỗi truy vấn doanh thu: %s", err)
	}
	if doanhThuResult == nil {
		return "", fmt.Errorf("bản ghi doanh thu không tồn tại")
	}

	return string(doanhThuResult), nil
}

// Query queries a product record
func (s *SmartContract) Query(ctx contractapi.TransactionContextInterface, params string) (string, error) {
	var data Data
	if err := json.Unmarshal([]byte(params), &data); err != nil {
		return "", fmt.Errorf("lỗi phân tích params: %s", err)
	}

	key, err := ctx.GetStub().CreateCompositeKey(data.NhaSanXuat, []string{data.NhaSanXuat, data.ID})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key: %s", err)
	}

	queryResult, err := ctx.GetStub().GetState(key)
	if err != nil {
		return "", fmt.Errorf("lỗi truy vấn: %s", err)
	}
	if queryResult == nil {
		return "", fmt.Errorf("bản ghi không tồn tại")
	}

	return string(queryResult), nil
}

// QueryByAuthor queries products by manufacturer
func (s *SmartContract) QueryByAuthor(ctx contractapi.TransactionContextInterface, params string) (string, error) {
	var data Data
	if err := json.Unmarshal([]byte(params), &data); err != nil {
		return "", fmt.Errorf("lỗi phân tích params: %s", err)
	}

	keyIterator, err := ctx.GetStub().GetStateByPartialCompositeKey(data.NhaSanXuat, []string{data.NhaSanXuat})
	if err != nil {
		return "", fmt.Errorf("lỗi truy vấn: %s", err)
	}
	defer keyIterator.Close()

	var buffer bytes.Buffer
	buffer.WriteString("[")
	first := true
	for keyIterator.HasNext() {
		item, err := keyIterator.Next()
		if err != nil {
			return "", fmt.Errorf("lỗi lặp truy vấn: %s", err)
		}
		if !first {
			buffer.WriteString(",")
		}
		buffer.WriteString(`{"Value":`)
		buffer.Write(item.Value)
		buffer.WriteString("}")
		first = false
	}
	buffer.WriteString("]")

	return buffer.String(), nil
}

// QueryHistory queries product history
func (s *SmartContract) QueryHistory(ctx contractapi.TransactionContextInterface, params string) (string, error) {
	var data Data
	if err := json.Unmarshal([]byte(params), &data); err != nil {
		return "", fmt.Errorf("lỗi phân tích params: %s", err)
	}

	key, err := ctx.GetStub().CreateCompositeKey(data.NhaSanXuat, []string{data.NhaSanXuat, data.ID})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key: %s", err)
	}

	queryIterator, err := ctx.GetStub().GetHistoryForKey(key)
	if err != nil {
		return "", fmt.Errorf("lỗi truy vấn lịch sử: %s", err)
	}
	defer queryIterator.Close()

	var buffer bytes.Buffer
	buffer.WriteString("[")
	first := true
	for queryIterator.HasNext() {
		item, err := queryIterator.Next()
		if err != nil {
			return "", fmt.Errorf("lỗi lặp truy vấn lịch sử: %s", err)
		}
		if !first {
			buffer.WriteString(",")
		}
		buffer.WriteString(`{"TxId":"`)
		buffer.WriteString(item.TxId)
		buffer.WriteString(`","Value":`)
		buffer.Write(item.Value)
		buffer.WriteString(`,"Timestamp":"`)
		buffer.WriteString(time.Unix(item.Timestamp.Seconds, int64(item.Timestamp.Nanos)).String())
		buffer.WriteString(`","IsDelete":"`)
		buffer.WriteString(strconv.FormatBool(item.IsDelete))
		buffer.WriteString(`"}`)
		first = false
	}
	buffer.WriteString("]")

	return buffer.String(), nil
}

// QueryHistoryByMaDongGoi queries product history by package code
func (s *SmartContract) QueryHistoryByMaDongGoi(ctx contractapi.TransactionContextInterface, params string) (string, error) {
	var data Document
	if err := json.Unmarshal([]byte(params), &data); err != nil {
		return "", fmt.Errorf("lỗi phân tích params: %s", err)
	}

	keyMaDongGoi, err := ctx.GetStub().CreateCompositeKey(data.Key, []string{data.Key, "MaDongGoi"})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key mã đóng gói: %s", err)
	}

	queryResult, err := ctx.GetStub().GetState(keyMaDongGoi)
	if err != nil {
		return "", fmt.Errorf("lỗi truy vấn mã đóng gói: %s", err)
	}
	if queryResult == nil {
		return "", fmt.Errorf("mã đóng gói %s không tồn tại", keyMaDongGoi)
	}

	var doc Document
	if err := json.Unmarshal(queryResult, &doc); err != nil {
		return "", fmt.Errorf("lỗi phân tích bản ghi mã đóng gói: %s", err)
	}

	keySanPham, err := ctx.GetStub().CreateCompositeKey(doc.NhaSanXuat, []string{doc.NhaSanXuat, doc.ID})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key sản phẩm: %s", err)
	}

	queryIterator, err := ctx.GetStub().GetHistoryForKey(keySanPham)
	if err != nil {
		return "", fmt.Errorf("lỗi truy vấn lịch sử: %s", err)
	}
	defer queryIterator.Close()

	var buffer bytes.Buffer
	buffer.WriteString("[")
	first := true
	for queryIterator.HasNext() {
		item, err := queryIterator.Next()
		if err != nil {
			return "", fmt.Errorf("lỗi lặp truy vấn lịch sử: %s", err)
		}
		if !first {
			buffer.WriteString(",")
		}
		buffer.WriteString(`{"TxId":"`)
		buffer.WriteString(item.TxId)
		buffer.WriteString(`","Value":`)
		buffer.Write(item.Value)
		buffer.WriteString(`,"Timestamp":"`)
		buffer.WriteString(time.Unix(item.Timestamp.Seconds, int64(item.Timestamp.Nanos)).String())
		buffer.WriteString(`","IsDelete":"`)
		buffer.WriteString(strconv.FormatBool(item.IsDelete))
		buffer.WriteString(`"}`)
		first = false
	}
	buffer.WriteString("]")

	return buffer.String(), nil
}

// GetHashValue gets a specific history record by index
func (s *SmartContract) GetHashValue(ctx contractapi.TransactionContextInterface, params string) (string, error) {
	var data getHashValue
	if err := json.Unmarshal([]byte(params), &data); err != nil {
		return "", fmt.Errorf("lỗi phân tích params: %s", err)
	}

	key, err := ctx.GetStub().CreateCompositeKey(data.NhaSanXuat, []string{data.NhaSanXuat, data.ID})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key: %s", err)
	}

	queryIterator, err := ctx.GetStub().GetHistoryForKey(key)
	if err != nil {
		return "", fmt.Errorf("lỗi truy vấn lịch sử: %s", err)
	}
	defer queryIterator.Close()

	var buffer bytes.Buffer
	buffer.WriteString("[")
	index, err := strconv.Atoi(data.Index)
	if err != nil {
		return "", fmt.Errorf("lỗi phân tích chỉ số: %s", err)
	}
	count := 0
	for queryIterator.HasNext() {
		item, err := queryIterator.Next()
		if err != nil {
			return "", fmt.Errorf("lỗi lặp truy vấn lịch sử: %s", err)
		}
		if count == index {
			buffer.WriteString(`{"TxId":"`)
			buffer.WriteString(item.TxId)
			buffer.WriteString(`","Value":`)
			buffer.Write(item.Value)
			buffer.WriteString(`,"Timestamp":"`)
			buffer.WriteString(time.Unix(item.Timestamp.Seconds, int64(item.Timestamp.Nanos)).String())
			buffer.WriteString(`","IsDelete":"`)
			buffer.WriteString(strconv.FormatBool(item.IsDelete))
			buffer.WriteString(`"}`)
			break
		}
		count++
	}
	buffer.WriteString("]")

	return buffer.String(), nil
}

// QueryListSanPham queries the user's product list
func (s *SmartContract) QueryListSanPham(ctx contractapi.TransactionContextInterface) (string, error) {
	certID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return "", fmt.Errorf("không thể lấy ID người dùng: %s", err)
	}
	owner := getUsernameFromCertificate(certID)

	keyDanhSach, err := ctx.GetStub().CreateCompositeKey(owner, []string{owner, "danhSachSanPham"})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key danh sách: %s", err)
	}

	danhSachResult, err := ctx.GetStub().GetState(keyDanhSach)
	if err != nil {
		return "", fmt.Errorf("lỗi truy vấn danh sách: %s", err)
	}
	if danhSachResult == nil {
		return "", fmt.Errorf("danh sách sản phẩm không tồn tại")
	}

	var result DanhSachSanPham
	if err := json.Unmarshal(danhSachResult, &result); err != nil {
		return "", fmt.Errorf("lỗi phân tích danh sách: %s", err)
	}

	var buffer bytes.Buffer
	buffer.WriteString("[")
	for i := len(result.DanhSach) - 1; i >= 0; i-- {
		queryResult, err := ctx.GetStub().GetState(result.DanhSach[i])
		if err != nil {
			return "", fmt.Errorf("lỗi truy vấn sản phẩm: %s", err)
		}
		if queryResult == nil {
			return "", fmt.Errorf("sản phẩm không tồn tại")
		}
		if i == len(result.DanhSach)-1 {
			buffer.WriteString(`{"SoLuong":`)
			buffer.WriteString(strconv.Itoa(len(result.DanhSach)))
			buffer.WriteString("},")
		}
		buffer.WriteString(`{"Value":`)
		buffer.Write(queryResult)
		buffer.WriteString("}")
		if i > 0 {
			buffer.WriteString(",")
		}
	}
	buffer.WriteString("]")

	return buffer.String(), nil
}

// QueryListSanPhamTheoPageIndexVaPageSize queries products with pagination
func (s *SmartContract) QueryListSanPhamTheoPageIndexVaPageSize(ctx contractapi.TransactionContextInterface, params string) (string, error) {
	certID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return "", fmt.Errorf("không thể lấy ID người dùng: %s", err)
	}
	owner := getUsernameFromCertificate(certID)

	var data DanhSachSanPhamKemPageIndexVaPageSize
	if err := json.Unmarshal([]byte(params), &data); err != nil {
		return "", fmt.Errorf("lỗi phân tích params: %s", err)
	}

	pageSize, err := strconv.Atoi(data.PageSize)
	if err != nil {
		return "", fmt.Errorf("lỗi phân tích pageSize: %s", err)
	}
	pageIndex, err := strconv.Atoi(data.PageIndex)
	if err != nil {
		return "", fmt.Errorf("lỗi phân tích pageIndex: %s", err)
	}

	keyDanhSach, err := ctx.GetStub().CreateCompositeKey(owner, []string{owner, "danhSachSanPham"})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key danh sách: %s", err)
	}

	danhSachResult, err := ctx.GetStub().GetState(keyDanhSach)
	if err != nil {
		return "", fmt.Errorf("lỗi truy vấn danh sách: %s", err)
	}
	if danhSachResult == nil {
		return "", fmt.Errorf("danh sách sản phẩm không tồn tại")
	}

	var result DanhSachSanPham
	if err := json.Unmarshal(danhSachResult, &result); err != nil {
		return "", fmt.Errorf("lỗi phân tích danh sách: %s", err)
	}

	var buffer bytes.Buffer
	buffer.WriteString("[")
	buffer.WriteString(`{"SoLuong":`)
	buffer.WriteString(strconv.Itoa(len(result.DanhSach)))
	buffer.WriteString("},")

	endIndex := len(result.DanhSach) - pageSize*(pageIndex-1) - 1
	startIndex := endIndex - pageSize + 1
	if startIndex < 0 {
		startIndex = 0
	}

	for i := endIndex; i >= startIndex && i < len(result.DanhSach); i-- {
		queryResult, err := ctx.GetStub().GetState(result.DanhSach[i])
		if err != nil {
			return "", fmt.Errorf("lỗi truy vấn sản phẩm: %s", err)
		}
		if queryResult == nil {
			return "", fmt.Errorf("sản phẩm không tồn tại")
		}
		buffer.WriteString(`{"Value":`)
		buffer.Write(queryResult)
		buffer.WriteString("}")
		if i > startIndex {
			buffer.WriteString(",")
		}
	}
	buffer.WriteString("]")

	return buffer.String(), nil
}

// stringToRune converts string to rune array
func stringToRune(s string) ([]string, int) {
	ll := utf8.RuneCountInString(s)
	texts := make([]string, 0, ll)
	for _, runeValue := range s {
		texts = append(texts, string(runeValue))
	}
	return texts, ll
}

// binarySearch performs binary search on sorted string slice
func binarySearch(sortedArray []string, key string, low, high int) int {
	if high < low {
		return -1
	}
	middle := (low + high) / 2
	if key == sortedArray[middle] {
		return middle
	}
	if key < sortedArray[middle] {
		return binarySearch(sortedArray, key, low, middle-1)
	}
	return binarySearch(sortedArray, key, middle+1, high)
}

// removeAccentChar removes accent from a character
func removeAccentChar(ch string) string {
	index := binarySearch(SOURCE_CHARACTERS, ch, 0, LL_LENGTH)
	if index >= 0 {
		return DESTINATION_CHARACTERS[index]
	}
	return ch
}

// removeAccent removes accents from a string
func removeAccent(s string) string {
	var buffer strings.Builder
	for _, runeValue := range s {
		buffer.WriteString(removeAccentChar(string(runeValue)))
	}
	return buffer.String()
}

// SearchSanPham searches for products by keyword
func (s *SmartContract) SearchSanPham(ctx contractapi.TransactionContextInterface, params string) (string, error) {
	certID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return "", fmt.Errorf("không thể lấy ID người dùng: %s", err)
	}
	owner := getUsernameFromCertificate(certID)

	var data SearchSanPham
	if err := json.Unmarshal([]byte(params), &data); err != nil {
		return "", fmt.Errorf("lỗi phân tích params: %s", err)
	}

	keyword := removeAccent(data.Keyword)
	keyword = strings.ReplaceAll(keyword, " ", "")

	keyDanhSach, err := ctx.GetStub().CreateCompositeKey(owner, []string{owner, "danhSachSanPham"})
	if err != nil {
		return "", fmt.Errorf("lỗi tạo key danh sách: %s", err)
	}

	danhSachResult, err := ctx.GetStub().GetState(keyDanhSach)
	if err != nil {
		return "", fmt.Errorf("lỗi truy vấn danh sách: %s", err)
	}
	if danhSachResult == nil {
		return "", fmt.Errorf("danh sách sản phẩm không tồn tại")
	}

	var result DanhSachSanPham
	if err := json.Unmarshal(danhSachResult, &result); err != nil {
		return "", fmt.Errorf("lỗi phân tích danh sách: %s", err)
	}

	var buffer bytes.Buffer
	count := 0
	for i := len(result.DanhSach) - 1; i >= 0; i-- {
		queryResult, err := ctx.GetStub().GetState(result.DanhSach[i])
		if err != nil {
			return "", fmt.Errorf("lỗi truy vấn sản phẩm: %s", err)
		}
		if queryResult == nil {
			return "", fmt.Errorf("sản phẩm không tồn tại")
		}

		var queryItem Data
		if err := json.Unmarshal(queryResult, &queryItem); err != nil {
			return "", fmt.Errorf("lỗi phân tích sản phẩm: %s", err)
		}

		tenSanPhamKhongDau := removeAccent(queryItem.TenSanPham)
		tenSanPhamKhongDau = strings.ReplaceAll(tenSanPhamKhongDau, " ", "")
		if score := matchr.JaroWinkler(keyword, tenSanPhamKhongDau, true); score >= 0.6 {
			if count > 0 {
				buffer.WriteString(",")
			}
			buffer.WriteString(`{"Value":`)
			buffer.Write(queryResult)
			buffer.WriteString("}")
			count++
		} else {
			tenSanPhamKhongDau = removeAccent(queryItem.TenSanPham)
			words := strings.Split(tenSanPhamKhongDau, " ")
			for _, word := range words {
				if score := matchr.JaroWinkler(keyword, word, true); score >= 0.72 {
					if count > 0 {
						buffer.WriteString(",")
					}
					buffer.WriteString(`{"Value":`)
					buffer.Write(queryResult)
				}
				count++
				break
			}
		}
	}
	resultStr := buffer.String()
	if count > 0 {
		resultStr = fmt.Sprintf(`[{"SoLuong":%d},%s]`, count, resultStr)
	} else {
		resultStr = "[]"
	}

	return resultStr, nil
}

// GetID returns the client identity
func (s *SmartContract) GetID(ctx contractapi.TransactionContextInterface) (string, error) {
	owner, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return "", fmt.Errorf("không thể lấy ID người dùng: %s", err)
	}
	return owner, nil
}
