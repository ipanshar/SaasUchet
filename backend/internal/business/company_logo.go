package business

import (
	"bytes"
	"encoding/binary"
	"encoding/xml"
	"fmt"
	"image"
	"image/color"
	_ "image/jpeg"
	"image/png"
	"io"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/srwiley/oksvg"
	"github.com/srwiley/rasterx"
)

const (
	maxCompanyLogoBytes  = 2 << 20
	minCompanyLogoPixels = 100
	maxCompanyLogoPixels = 600
)

var pngSignature = []byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'}

func companyLogoURL(companyID string, updatedAt time.Time) string {
	return fmt.Sprintf("/api/v1/companies/%s/logo?v=%d", companyID, updatedAt.UTC().Unix())
}

func normalizeCompanyLogo(filename string, data []byte) ([]byte, error) {
	if len(data) == 0 {
		return nil, fmt.Errorf("файл логотипа пустой")
	}
	if len(data) > maxCompanyLogoBytes {
		return nil, fmt.Errorf("логотип должен быть не больше 2 МБ")
	}

	switch normalizedLogoExtension(filename) {
	case ".png", ".jpg", ".jpeg":
		return normalizeRasterLogo(data)
	case ".svg":
		return normalizeSVGLogo(data)
	case ".ico":
		return normalizeICOLogo(data)
	default:
		return nil, fmt.Errorf("поддерживаются только ICO, PNG, JPG и SVG")
	}
}

func normalizedLogoExtension(filename string) string {
	name := strings.TrimSpace(strings.ToLower(filename))
	if dot := strings.LastIndexByte(name, '.'); dot >= 0 {
		ext := name[dot:]
		if ext == ".swg" {
			return ".svg"
		}
		return ext
	}
	return ""
}

func normalizeRasterLogo(data []byte) ([]byte, error) {
	cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("не удалось прочитать изображение")
	}
	if err := validateCompanyLogoDimensions(cfg.Width, cfg.Height); err != nil {
		return nil, err
	}
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("не удалось декодировать изображение")
	}
	return encodeLogoPNG(img)
}

func normalizeSVGLogo(data []byte) ([]byte, error) {
	width, height, err := parseSVGDimensions(data)
	if err != nil {
		return nil, err
	}
	if err := validateCompanyLogoDimensions(width, height); err != nil {
		return nil, err
	}

	icon, err := oksvg.ReadIconStream(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("не удалось прочитать SVG")
	}

	img := image.NewRGBA(image.Rect(0, 0, width, height))
	icon.SetTarget(0, 0, float64(width), float64(height))
	scanner := rasterx.NewScannerGV(width, height, img, img.Bounds())
	dasher := rasterx.NewDasher(width, height, scanner)
	icon.Draw(dasher, 1.0)
	return encodeLogoPNG(img)
}

func normalizeICOLogo(data []byte) ([]byte, error) {
	img, err := decodeICOImage(data)
	if err != nil {
		return nil, err
	}
	bounds := img.Bounds()
	if err := validateCompanyLogoDimensions(bounds.Dx(), bounds.Dy()); err != nil {
		return nil, err
	}
	return encodeLogoPNG(img)
}

func validateCompanyLogoDimensions(width int, height int) error {
	if width <= 0 || height <= 0 {
		return fmt.Errorf("не удалось определить размер логотипа")
	}
	if width != height {
		return fmt.Errorf("логотип должен быть квадратным")
	}
	if width < minCompanyLogoPixels || width > maxCompanyLogoPixels {
		return fmt.Errorf("размер логотипа должен быть от 100x100 до 600x600")
	}
	return nil
}

func encodeLogoPNG(img image.Image) ([]byte, error) {
	var buffer bytes.Buffer
	if err := png.Encode(&buffer, img); err != nil {
		return nil, fmt.Errorf("не удалось сохранить логотип")
	}
	return buffer.Bytes(), nil
}

func parseSVGDimensions(data []byte) (int, int, error) {
	decoder := xml.NewDecoder(bytes.NewReader(data))
	for {
		token, err := decoder.Token()
		if err != nil {
			if err == io.EOF {
				break
			}
			return 0, 0, fmt.Errorf("не удалось прочитать SVG")
		}
		start, ok := token.(xml.StartElement)
		if !ok {
			continue
		}

		var widthValue string
		var heightValue string
		var viewBoxValue string
		for _, attr := range start.Attr {
			switch strings.ToLower(attr.Name.Local) {
			case "width":
				widthValue = attr.Value
			case "height":
				heightValue = attr.Value
			case "viewbox":
				viewBoxValue = attr.Value
			}
		}

		if widthValue != "" && heightValue != "" {
			width, err := parseSVGUnit(widthValue)
			if err != nil {
				return 0, 0, err
			}
			height, err := parseSVGUnit(heightValue)
			if err != nil {
				return 0, 0, err
			}
			return width, height, nil
		}
		if viewBoxValue != "" {
			return parseSVGViewBox(viewBoxValue)
		}
		break
	}
	return 0, 0, fmt.Errorf("SVG должен содержать width/height или viewBox")
}

func parseSVGUnit(value string) (int, error) {
	trimmed := strings.TrimSpace(strings.ToLower(value))
	if trimmed == "" {
		return 0, fmt.Errorf("SVG содержит пустой размер")
	}
	if strings.Contains(trimmed, "%") {
		return 0, fmt.Errorf("SVG с процентными размерами не поддерживается")
	}
	if strings.HasSuffix(trimmed, "px") {
		trimmed = strings.TrimSpace(strings.TrimSuffix(trimmed, "px"))
	}
	for _, unit := range []string{"pt", "pc", "cm", "mm", "in", "em", "rem", "vh", "vw"} {
		if strings.HasSuffix(trimmed, unit) {
			return 0, fmt.Errorf("SVG с единицами %s не поддерживается", unit)
		}
	}
	number, err := strconv.ParseFloat(trimmed, 64)
	if err != nil || number <= 0 {
		return 0, fmt.Errorf("не удалось определить размер SVG")
	}
	return int(math.Round(number)), nil
}

func parseSVGViewBox(value string) (int, int, error) {
	fields := strings.Fields(strings.ReplaceAll(value, ",", " "))
	if len(fields) != 4 {
		return 0, 0, fmt.Errorf("не удалось определить размер SVG")
	}
	width, err := strconv.ParseFloat(fields[2], 64)
	if err != nil || width <= 0 {
		return 0, 0, fmt.Errorf("не удалось определить ширину SVG")
	}
	height, err := strconv.ParseFloat(fields[3], 64)
	if err != nil || height <= 0 {
		return 0, 0, fmt.Errorf("не удалось определить высоту SVG")
	}
	return int(math.Round(width)), int(math.Round(height)), nil
}

func decodeICOImage(data []byte) (image.Image, error) {
	if len(data) < 6 {
		return nil, fmt.Errorf("ICO поврежден или слишком короткий")
	}
	if binary.LittleEndian.Uint16(data[0:2]) != 0 || binary.LittleEndian.Uint16(data[2:4]) != 1 {
		return nil, fmt.Errorf("неверный формат ICO")
	}

	count := int(binary.LittleEndian.Uint16(data[4:6]))
	if count <= 0 {
		return nil, fmt.Errorf("ICO не содержит изображений")
	}
	if len(data) < 6+(count*16) {
		return nil, fmt.Errorf("ICO поврежден")
	}

	var chosen image.Image
	bestSize := 0
	for index := 0; index < count; index++ {
		offset := 6 + (index * 16)
		size := int(binary.LittleEndian.Uint32(data[offset+8 : offset+12]))
		imageOffset := int(binary.LittleEndian.Uint32(data[offset+12 : offset+16]))
		if size <= 0 || imageOffset < 0 || imageOffset+size > len(data) {
			continue
		}
		img, err := decodeICOEntry(data[offset:offset+16], data[imageOffset:imageOffset+size])
		if err != nil {
			continue
		}
		bounds := img.Bounds()
		width := bounds.Dx()
		height := bounds.Dy()
		if width != height {
			continue
		}
		if width < minCompanyLogoPixels || width > maxCompanyLogoPixels {
			continue
		}
		if width > bestSize {
			chosen = img
			bestSize = width
		}
	}
	if chosen == nil {
		return nil, fmt.Errorf("ICO должен содержать квадратный логотип от 100x100 до 600x600")
	}
	return chosen, nil
}

func decodeICOEntry(entry []byte, raw []byte) (image.Image, error) {
	if bytes.HasPrefix(raw, pngSignature) {
		return png.Decode(bytes.NewReader(raw))
	}

	bitCount := int(binary.LittleEndian.Uint16(entry[6:8]))
	return decodeICODIB(raw, bitCount)
}

func decodeICODIB(raw []byte, bitCount int) (image.Image, error) {
	if len(raw) < 40 {
		return nil, fmt.Errorf("ICO bitmap поврежден")
	}

	headerSize := int(binary.LittleEndian.Uint32(raw[0:4]))
	if headerSize < 40 || len(raw) < headerSize {
		return nil, fmt.Errorf("ICO bitmap содержит неподдерживаемый DIB-заголовок")
	}

	width := int(int32(binary.LittleEndian.Uint32(raw[4:8])))
	heightValue := int(int32(binary.LittleEndian.Uint32(raw[8:12])))
	if width <= 0 || heightValue == 0 {
		return nil, fmt.Errorf("не удалось определить размер ICO")
	}

	height := int(math.Abs(float64(heightValue))) / 2
	if height <= 0 {
		return nil, fmt.Errorf("не удалось определить высоту ICO")
	}

	compression := binary.LittleEndian.Uint32(raw[16:20])
	if compression != 0 {
		return nil, fmt.Errorf("ICO сжатие не поддерживается")
	}

	switch bitCount {
	case 32:
		return decodeICO32(raw[headerSize:], width, height)
	case 24:
		return decodeICO24(raw[headerSize:], width, height)
	default:
		return nil, fmt.Errorf("ICO с глубиной %d бит не поддерживается", bitCount)
	}
}

func decodeICO32(data []byte, width int, height int) (image.Image, error) {
	rowSize := width * 4
	if len(data) < rowSize*height {
		return nil, fmt.Errorf("ICO bitmap поврежден")
	}
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	for y := 0; y < height; y++ {
		srcRow := (height - 1 - y) * rowSize
		for x := 0; x < width; x++ {
			offset := srcRow + (x * 4)
			img.SetRGBA(x, y, color.RGBA{
				R: data[offset+2],
				G: data[offset+1],
				B: data[offset],
				A: data[offset+3],
			})
		}
	}
	return img, nil
}

func decodeICO24(data []byte, width int, height int) (image.Image, error) {
	rowSize := ((width * 3) + 3) &^ 3
	if len(data) < rowSize*height {
		return nil, fmt.Errorf("ICO bitmap поврежден")
	}
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	for y := 0; y < height; y++ {
		srcRow := (height - 1 - y) * rowSize
		for x := 0; x < width; x++ {
			offset := srcRow + (x * 3)
			img.SetRGBA(x, y, color.RGBA{
				R: data[offset+2],
				G: data[offset+1],
				B: data[offset],
				A: 0xff,
			})
		}
	}
	return img, nil
}
