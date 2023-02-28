// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

// import "@openzeppelin/contracts/utils/Base64.sol";
library Base64 {
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    function encode(bytes memory data) internal pure returns (string memory) {
        if(data.length == 0) return "";
        string memory table = _TABLE;
        string memory result = new string(4 * ((data.length + 2) / 3));
        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {
            } {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }
        return result;
    }
}

/*
    String Slice Functions
    Taken from @Arachnid/src/strings.sol
*/

struct slice {
    uint _len;
    uint _ptr;
}

function slice_join(slice memory self, slice[] memory parts) pure returns (string memory) {
    if (parts.length == 0)
        return "";

    uint length = self._len * (parts.length - 1);
    for(uint i = 0; i < parts.length; i++)
        length += parts[i]._len;

    string memory ret = new string(length);
    uint retptr;
    assembly { retptr := add(ret, 32) }

    for(uint i = 0; i < parts.length; i++) {
        slice_memcpy(retptr, parts[i]._ptr, parts[i]._len);
        retptr += parts[i]._len;
        if (i < parts.length - 1) {
            slice_memcpy(retptr, self._ptr, self._len);
            retptr += self._len;
        }
    }

    return ret;
}

function slice_memcpy(uint dest, uint src, uint len) pure {
    // Copy word-length chunks while possible
    for(; len >= 32; len -= 32) {
        assembly {
            mstore(dest, mload(src))
        }
        dest += 32;
        src += 32;
    }

    // Copy remaining bytes
    uint _mask = type(uint).max;
    if (len > 0) {
        _mask = 256 ** (32 - len) - 1;
    }
    assembly {
        let srcpart := and(mload(src), not(_mask))
        let destpart := and(mload(dest), _mask)
        mstore(dest, or(destpart, srcpart))
    }
}

function slice_toSlice(string memory self) pure returns (slice memory) {
    uint ptr;
    assembly {
        ptr := add(self, 0x20)
    }
    return slice(bytes(self).length, ptr);
}

/*
    Utility Functions
*/

bytes16 constant HEX_SYMBOLS = "0123456789ABCDEF";
function get3Hex(uint8 valueA, uint8 valueB, uint8 valueC) pure returns (string memory) {
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

bytes16 constant DECIMAL_SYMBOLS = "0123456789";
function uint256ToStringFast(uint256 _i) pure returns (string memory) {
    // Only works for values < 1000
    bytes memory buffer;
    if(_i < 10) {
        buffer = new bytes(1);
        buffer[0] = DECIMAL_SYMBOLS[_i];
    }
    else if(_i < 100) {
        buffer = new bytes(2);
        buffer[0] = DECIMAL_SYMBOLS[_i / 10];
        buffer[1] = DECIMAL_SYMBOLS[_i % 10];
    }
    else {
        buffer = new bytes(3);
        buffer[0] = DECIMAL_SYMBOLS[(_i / 10) / 10];
        buffer[1] = DECIMAL_SYMBOLS[(_i / 10) % 10];
        buffer[2] = DECIMAL_SYMBOLS[_i % 10];
    }

    return string(buffer);
}

contract PixelPictasiaUtils {
    uint256[256] private CRC_TABLE;

    constructor() payable {
        createCRCTable();
    }

    function crc(bytes1[] memory _buf, uint256 _len) public view returns (uint256) {
        return update_crc(4294967295, _buf, _len) ^ 4294967295;
    }

    function adler32(bytes1[] memory _buf, uint256 _len) public pure returns (uint256) {
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

    function createPNGString() public view returns (string memory) {
        bytes memory imageData = createPNG();
        string memory imageDataString = string(imageData);

        return string(abi.encodePacked("data:image/png;base64,", Base64.encode(abi.encodePacked(imageDataString))));
    }

    function createPNG() public view returns (bytes memory) {
        uint256 i = 0;
        bytes1[] memory imageData = new bytes1[](100);

        (imageData, i) = addPNGSignature(imageData, i);
        (imageData, i) = addIHDRChunck(imageData, i, 3, 1);
        (imageData, i) = addIDATChunck(imageData, i);
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

    function addIDATChunck(bytes1[] memory _imageData, uint256 _i) private view returns (bytes1[] memory, uint256) {
        // (Skip length for now)
        uint256 iLengthIdx = _i;

        _i += 4;

        uint256 iCRCStart = _i;

        // Type = IDAT
        _imageData[_i++] = hex"49";
        _imageData[_i++] = hex"44";
        _imageData[_i++] = hex"41";
        _imageData[_i++] = hex"54";

        // Data

        uint256 iLengthStart = _i;

        // CMF and FLG
        _imageData[_i++] = hex"78";
        _imageData[_i++] = hex"01";

        // BFINAL and BTYPE
        _imageData[_i++] = hex"01";

        // (Skip ZLIB length and ones complement for now)
        uint256 iZLIBLengthIdx = _i;

        _i += 4;

        uint256 iADLER32Start = _i;
        uint256 iZLIBLengthStart = _i;

        // Add a row of pixels.
        _imageData[_i++] = hex"00"; // Filter

        _imageData[_i++] = hex"FF";
        _imageData[_i++] = hex"00";
        _imageData[_i++] = hex"00";

        _imageData[_i++] = hex"00";
        _imageData[_i++] = hex"FF";
        _imageData[_i++] = hex"00";

        _imageData[_i++] = hex"00";
        _imageData[_i++] = hex"00";
        _imageData[_i++] = hex"FF";

        uint256 iADLER32End = _i;
        uint256 iZLIBLengthEnd = _i;

        // ADLER32
        (_imageData, _i) = addADLER32(_imageData, _i, iADLER32Start, iADLER32End);

        uint256 iLengthEnd = _i;
        uint256 iCRCEnd = _i;

        // CRC
        (_imageData, _i) = addCRC(_imageData, _i, iCRCStart, iCRCEnd);

        // Fill in length. Do not use _i since we are backfilling an earlier index.
        (_imageData, iLengthIdx) = add4ByteValue(_imageData, iLengthIdx, iLengthEnd - iLengthStart);
        (_imageData, iZLIBLengthIdx) = add2ByteValue(_imageData, iZLIBLengthIdx, iZLIBLengthEnd - iZLIBLengthStart);
        (_imageData, iZLIBLengthIdx) = add2ByteValue(_imageData, iZLIBLengthIdx, 65535 - (iZLIBLengthEnd - iZLIBLengthStart));

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
}