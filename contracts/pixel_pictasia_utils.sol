// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

struct PNGData {
    bytes1[] red;
    bytes1[] green;
    bytes1[] blue;
}

bytes16 constant HEX_SYMBOLS = "0123456789ABCDEF";
function get3Hex(uint256 valueA, uint256 valueB, uint256 valueC) pure returns (string memory) {
    // Each value must be < 256.
    bytes memory buffer = new bytes(7);
    buffer[0] = "#";
    buffer[1] = HEX_SYMBOLS[(valueA & 0xf0) >> 4];
    buffer[2] = HEX_SYMBOLS[valueA & 0xf];
    buffer[3] = HEX_SYMBOLS[(valueB & 0xf0) >> 4];
    buffer[4] = HEX_SYMBOLS[valueB & 0xf];
    buffer[5] = HEX_SYMBOLS[(valueC & 0xf0) >> 4];
    buffer[6] = HEX_SYMBOLS[valueC & 0xf];

    return string(buffer);
}

contract PixelPictasiaUtils {
    uint256[256] private CRC_TABLE;

    constructor() payable {
        createCRCTable();
    }

    /*
        PNG Functions
    */

    function createPNG(uint256 _width, uint256 _height, PNGData memory pngData) public view returns (bytes memory) {
        uint256 i = 0;
        bytes1[] memory imageData = new bytes1[](80 + _height + 3 * _width * _height);

        (imageData, i) = addPNGSignature(imageData, i);
        (imageData, i) = addIHDRChunck(imageData, i, _width, _height);
        (imageData, i) = addIDATChunck(imageData, i, _width, _height, pngData);
        (imageData, i) = addIENDChunck(imageData, i);

        bytes memory trimmedImageData = new bytes(i);
        for(uint256 x = 0; x < i; x++) {
            trimmedImageData[x] = imageData[x];
        }

        return trimmedImageData;
    }

    function addPNGSignature(bytes1[] memory _imageData, uint256 _i) private pure returns (bytes1[] memory, uint256) {
        _imageData[_i++] = hex"89";
        _imageData[_i++] = hex"50";
        _imageData[_i++] = hex"4E";
        _imageData[_i++] = hex"47";
        _imageData[_i++] = hex"0D";
        _imageData[_i++] = hex"0A";
        _imageData[_i++] = hex"1A";
        _imageData[_i++] = hex"0A";

        return (_imageData, _i);
    }

    function addIHDRChunck(bytes1[] memory _imageData, uint256 _i, uint256 _width, uint256 _height) private view returns (bytes1[] memory, uint256) {
        // (Skip length for now)
        uint256 iLengthIdx = _i;
        _i += 4;

        uint256 iCRCStart = _i;

        // Type = IHDR
        _imageData[_i++] = hex"49";
        _imageData[_i++] = hex"48";
        _imageData[_i++] = hex"44";
        _imageData[_i++] = hex"52";

        // Data
        uint256 iLengthStart = _i;

        // Width
        (_imageData, _i) = add4ByteValue(_imageData, _i, _width);

        // Height
        (_imageData, _i) = add4ByteValue(_imageData, _i, _height);

        // Bit Depth
        _imageData[_i++] = hex"08";

        // Colour Type
        _imageData[_i++] = hex"02";

        // Compression Method
        _imageData[_i++] = hex"00";

        // Filter Method
        _imageData[_i++] = hex"00";

        // Interlace Method
        _imageData[_i++] = hex"00";

        uint256 iLengthEnd = _i;
        uint256 iCRCEnd = _i;

        // CRC
        (_imageData, _i) = addCRC(_imageData, _i, iCRCStart, iCRCEnd);

        // Fill in length. Do not use _i since we are backfilling an earlier index.
        (_imageData, iLengthIdx) = add4ByteValue(_imageData, iLengthIdx, iLengthEnd - iLengthStart);

        return (_imageData, _i);
    }

    // Use this to avoid "stack too deep" errors from excessive local variables.
    struct IDATStruct {
        uint256 iLengthIdx;
        uint256 iLengthStart;
        uint256 iLengthEnd;

        uint256 iZLIBLengthIdx;
        uint256 iZLIBLengthStart;
        uint256 iZLIBLengthEnd;

        uint256 iADLER32Start;
        uint256 iADLER32End;

        uint256 iCRCStart;
        uint256 iCRCEnd;
    }

    function addIDATChunck(bytes1[] memory _imageData, uint256 _i, uint256 _width, uint256 _height, PNGData memory pngData) private view returns (bytes1[] memory, uint256) {
        IDATStruct memory idatStruct = IDATStruct(0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        // (Skip length for now)
        idatStruct.iLengthIdx = _i;
        _i += 4;

        idatStruct.iCRCStart = _i;

        // Type = IDAT
        _imageData[_i++] = hex"49";
        _imageData[_i++] = hex"44";
        _imageData[_i++] = hex"41";
        _imageData[_i++] = hex"54";

        // Data
        idatStruct.iLengthStart = _i;

        // CMF and FLG
        _imageData[_i++] = hex"78";
        _imageData[_i++] = hex"01";

        // BFINAL and BTYPE
        _imageData[_i++] = hex"01";

        // (Skip ZLIB length and ones complement for now)
        idatStruct.iZLIBLengthIdx = _i;
        _i += 4;

        idatStruct.iADLER32Start = _i;
        idatStruct.iZLIBLengthStart = _i;

        // Add rows of pixels.
        uint256 c = 0;
        for(uint256 y = 0; y < _height; y++) {
            // Add the zero Filter Type at the start of each row.
            _imageData[_i++] = hex"00";

            for(uint256 x = 0; x < _width; x++) {
                _imageData[_i++] = pngData.red[c];
                _imageData[_i++] = pngData.green[c];
                _imageData[_i++] = pngData.blue[c];
                c++;
            }
        }

        idatStruct.iADLER32End = _i;
        idatStruct.iZLIBLengthEnd = _i;

        // ADLER32
        (_imageData, _i) = addADLER32(_imageData, _i, idatStruct.iADLER32Start, idatStruct.iADLER32End);

        idatStruct.iLengthEnd = _i;
        idatStruct.iCRCEnd = _i;

        // CRC
        (_imageData, _i) = addCRC(_imageData, _i, idatStruct.iCRCStart, idatStruct.iCRCEnd);

        // Fill in length. Do not use _i since we are backfilling an earlier index.
        (_imageData, idatStruct.iLengthIdx) = add4ByteValue(_imageData, idatStruct.iLengthIdx, idatStruct.iLengthEnd - idatStruct.iLengthStart);
        (_imageData, idatStruct.iZLIBLengthIdx) = add2ByteValue(_imageData, idatStruct.iZLIBLengthIdx, idatStruct.iZLIBLengthEnd - idatStruct.iZLIBLengthStart);
        (_imageData, idatStruct.iZLIBLengthIdx) = add2ByteValue(_imageData, idatStruct.iZLIBLengthIdx, 65535 - (idatStruct.iZLIBLengthEnd - idatStruct.iZLIBLengthStart));

        return (_imageData, _i);
    }

    function addIENDChunck(bytes1[] memory _imageData, uint256 _i) private view returns (bytes1[] memory, uint256) {
        // Length is always 0
        (_imageData, _i) = add4ByteValue(_imageData, _i, 0);

        uint256 iCRCStart = _i;

        // Type = IEND
        _imageData[_i++] = hex"49";
        _imageData[_i++] = hex"45";
        _imageData[_i++] = hex"4E";
        _imageData[_i++] = hex"44";

        uint256 iCRCEnd = _i;

        // CRC
        (_imageData, _i) = addCRC(_imageData, _i, iCRCStart, iCRCEnd);

        return (_imageData, _i);
    }

    function addADLER32(bytes1[] memory _imageData, uint256 _i, uint256 _iADLER32Start, uint256 _iADLER32End) private pure returns (bytes1[] memory, uint256) {
        uint256 L = _iADLER32End - _iADLER32Start;

        uint256 b = 0;
        bytes1[] memory buf = new bytes1[](L);

        for(uint256 x = _iADLER32Start; x < _iADLER32End; x++) {
            buf[b++] = _imageData[x];
        }

        uint256 adler32Value = adler32(buf, L);
        (_imageData, _i) = add4ByteValue(_imageData, _i, adler32Value);

        return (_imageData, _i);
    }

    function addCRC(bytes1[] memory _imageData, uint256 _i, uint256 _iCRCStart, uint256 _iCRCEnd) private view returns (bytes1[] memory, uint256) {
        uint256 L = _iCRCEnd - _iCRCStart;

        uint256 b = 0;
        bytes1[] memory buf = new bytes1[](L);

        for(uint256 x = _iCRCStart; x < _iCRCEnd; x++) {
            buf[b++] = _imageData[x];
        }

        uint256 crcValue = crc(buf, L);
        (_imageData, _i) = add4ByteValue(_imageData, _i, crcValue);

        return (_imageData, _i);
    }

    function add2ByteValue(bytes1[] memory _imageData, uint256 _i, uint256 _value) private pure returns (bytes1[] memory, uint256) {
        // _value must be able to be stored in 2 bytes (i.e. up to a max of FF FF)
        _imageData[_i++] = bytes1(uint8((_value & 0xff00) >> 8));
        _imageData[_i++] = bytes1(uint8((_value & 0xff)));

        return (_imageData, _i);
    }

    function add4ByteValue(bytes1[] memory _imageData, uint256 _i, uint256 _value) private pure returns (bytes1[] memory, uint256) {
        // _value must be able to be stored in 4 bytes (i.e. up to a max of FF FF FF FF)
        _imageData[_i++] = bytes1(uint8((_value & 0xff000000) >> 24));
        _imageData[_i++] = bytes1(uint8((_value & 0xff0000) >> 16));
        _imageData[_i++] = bytes1(uint8((_value & 0xff00) >> 8));
        _imageData[_i++] = bytes1(uint8((_value & 0xff)));

        return (_imageData, _i);
    }

    /*
        Checksum Functions
    */

    function crc(bytes1[] memory _buf, uint256 _len) private view returns (uint256) {
        return update_crc(4294967295, _buf, _len) ^ 4294967295;
    }

    function adler32(bytes1[] memory _buf, uint256 _len) private pure returns (uint256) {
        uint256 A = 1;
        uint256 B = 0;
        
        for(uint256 i = 0; i < _len; i++) {
            A = A + uint8(_buf[i]);
            B = B + A;
        }
        
        return B * 65536 + A;
    }

    function createCRCTable() private {
        for(uint256 n = 0; n < 256; n++) {
            uint256 c = n;

            for(uint256 k = 0; k < 8; k++) {
                if(c & 1 == 1) {
                    c = 3988292384 ^ (c >> 1);
                }
                else {
                    c = c >> 1;
                }
            }
            CRC_TABLE[n] = c;
        }
    }

    function update_crc(uint256 _crc, bytes1[] memory _buf, uint256 _len) private view returns (uint256) {
        uint256 c = _crc;

        for (uint256 n = 0; n < _len; n++) {
            c = CRC_TABLE[(c ^ uint8(_buf[n])) & 255] ^ (c >> 8);
        }
        
        return c;
    }
}