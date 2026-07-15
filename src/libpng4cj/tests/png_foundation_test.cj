package libpng4cj.tests

import libpng4cj.*

@Test
public class PngFoundationTestSuite {
    @TestCase
    public func recognizesPngSignature(): Unit {
        @Assert(isPngSignature(PNG_SIGNATURE), true)
        @Assert(isPngSignature([0x89, 0x50, 0x4e]), false)
        @Assert(isPngSignature([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x00]), false)
    }

    @TestCase
    public func readsAndWritesBigEndianUInt32(): Unit {
        let bytes: Array<Byte> = [0x00, 0x01, 0x02, 0x03, 0x04]
        let expected: Array<Byte> = [0x89, 0xab, 0xcd, 0xef]
        @Assert(readUInt32Be(bytes, 1), UInt32(0x01020304))
        @Assert(writeUInt32Be(UInt32(0x89abcdef)), expected)
    }

    @TestCase
    public func rejectsShortBigEndianInput(): Unit {
        var rejected = false
        try {
            readUInt32Be([0x01, 0x02, 0x03], 0)
        } catch (_: PngFormatException) {
            rejected = true
        }
        @Assert(rejected, true)
    }

    @TestCase
    public func validatesChunkTypeBits(): Unit {
        let ihdr: Array<Byte> = [0x49, 0x48, 0x44, 0x52]
        let text: Array<Byte> = [0x74, 0x45, 0x58, 0x74]
        @Assert(isValidChunkType(ihdr), true)
        @Assert(isValidChunkType([0x49, 0x48, 0x31, 0x52]), false)
        @Assert(isCriticalChunk(ihdr), true)
        @Assert(isCriticalChunk(text), false)
    }

    @TestCase
    public func matchesStandardCrc32Vector(): Unit {
        let vector: Array<Byte> = [
            0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39
        ]
        @Assert(pngCrc32(vector), UInt32(0xcbf43926))
    }

    @TestCase
    public func matchesIendChunkCrc(): Unit {
        let iend: Array<Byte> = [0x49, 0x45, 0x4e, 0x44]
        @Assert(pngChunkCrc32(iend, []), UInt32(0xae426082))
    }
}
