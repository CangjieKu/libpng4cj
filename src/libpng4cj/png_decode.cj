package libpng4cj

import std.collection.ArrayList

public class PngDecodedRows {
    public let ihdr: PngIhdr
    public let metadata: PngReadMetadata
    private let ownedRows: Array<Array<Byte>>

    init(ihdr: PngIhdr, metadata: PngReadMetadata, rows: Array<Array<Byte>>) {
        this.ihdr = ihdr
        this.metadata = metadata
        ownedRows = rows
    }

    public func rowCount(): Int64 {
        ownedRows.size
    }

    public func row(index: Int64): Array<Byte> {
        if (index < 0 || index >= ownedRows.size) {
            throw PngFormatException(InvalidArgument, index, "PNG row index is out of bounds")
        }
        ownedRows[index].clone()
    }

    public func rows(): Array<Array<Byte>> {
        let out = Array<Array<Byte>>(ownedRows.size, repeat: Array<Byte>())
        var index: Int64 = 0
        while (index < ownedRows.size) {
            out[index] = ownedRows[index].clone()
            index += 1
        }
        out
    }
}

private func appendIdatPayload(
    output: ArrayList<Byte>,
    payload: Array<Byte>,
    currentSize: UInt64,
    limits: PngReadLimits
): UInt64 {
    let nextSize = currentSize + UInt64(payload.size)
    if (nextSize < currentSize || nextSize > limits.maxCompressedBytes) {
        throw PngFormatException(
            DecodeLimitExceeded,
            -1,
            "combined IDAT data exceeds configured compressed-byte limit"
        )
    }
    var index: Int64 = 0
    while (index < payload.size) {
        output.add(payload[index])
        index += 1
    }
    nextSize
}

private func validatePaletteChunk(chunk: PngChunk, ihdr: PngIhdr): Unit {
    if (ihdr.colorType == Grayscale || ihdr.colorType == GrayscaleAlpha) {
        throw PngFormatException(InvalidPalette, chunk.offset, "PLTE is not allowed for grayscale PNG images")
    }
    if (chunk.length == UInt32(0) || chunk.length > UInt32(768) ||
        (chunk.length % UInt32(3)) != UInt32(0)) {
        throw PngFormatException(InvalidPalette, chunk.offset, "PLTE length must contain 1..256 RGB entries")
    }
    if (ihdr.colorType == Indexed) {
        let entries = chunk.length / UInt32(3)
        let maximumEntries = UInt32(1) << UInt32(ihdr.bitDepth)
        if (entries > maximumEntries) {
            throw PngFormatException(InvalidPalette, chunk.offset, "PLTE has too many entries for indexed bit depth")
        }
    }
}

private func expectedInflatedSize(ihdr: PngIhdr, limits: PngReadLimits): Int64 {
    let rowFrameBytes = ihdr.rowBytes + UInt64(1)
    let height = UInt64(ihdr.height)
    if (height > limits.maxInflatedBytes / rowFrameBytes) {
        throw PngFormatException(
            DecodeLimitExceeded,
            -1,
            "PNG rows exceed configured inflated-byte limit"
        )
    }
    Int64(rowFrameBytes * height)
}

private func decodeInflatedRows(inflated: Array<Byte>, ihdr: PngIhdr): Array<Array<Byte>> {
    let rowBytes = Int64(ihdr.rowBytes)
    let bytesPerPixel = pngFilterBytesPerPixel(ihdr)
    let rows = Array<Array<Byte>>(Int64(ihdr.height), repeat: Array<Byte>())
    var previous = Array<Byte>(rowBytes, repeat: 0)
    var sourceOffset: Int64 = 0
    var rowIndex: Int64 = 0
    while (rowIndex < rows.size) {
        let filterType = inflated[sourceOffset]
        let filtered = copyByteRange(inflated, sourceOffset + 1, rowBytes)
        let decoded = unfilterPngRow(filterType, filtered, previous, bytesPerPixel)
        rows[rowIndex] = decoded
        previous = decoded
        sourceOffset += rowBytes + 1
        rowIndex += 1
    }
    rows
}

public func decodePngNonInterlaced(
    bytes: Array<Byte>,
    limits: PngReadLimits,
    unknownPolicy: PngUnknownChunkPolicy
): PngDecodedRows {
    let session = PngReadSession(bytes, limits)
    let ihdr = session.readIhdr()
    if (ihdr.interlaceMethod != None) {
        throw PngFormatException(
            UnsupportedInterlace,
            28,
            "LP-S003 supports only non-interlaced PNG images"
        )
    }

    let compressed = ArrayList<Byte>()
    var compressedSize: UInt64 = UInt64(0)
    var seenPalette = false
    var seenTransparency = false
    var seenIdat = false
    var idatEnded = false
    var seenIend = false
    var palette = Array<Byte>()
    var transparency = ParsedPngTransparency()
    let metadataBuilder = PngMetadataBuilder()

    while (!seenIend) {
        if (session.remaining() == 0) {
            throw PngFormatException(MissingIend, session.position(), "PNG ended before IEND")
        }
        let chunk = session.readNextChunk()
        if (chunk.isType(PNG_CHUNK_IDAT)) {
            if (idatEnded) {
                throw PngFormatException(NonConsecutiveIdat, chunk.offset, "IDAT chunks must be consecutive")
            }
            if (ihdr.colorType == Indexed && !seenPalette) {
                throw PngFormatException(InvalidPalette, chunk.offset, "indexed PNG requires PLTE before IDAT")
            }
            let payload = chunk.payload()
            compressedSize = appendIdatPayload(compressed, payload, compressedSize, limits)
            seenIdat = true
        } else if (chunk.isType(PNG_CHUNK_IEND)) {
            if (chunk.length != UInt32(0)) {
                throw PngFormatException(InvalidIend, chunk.offset, "IEND chunk length must be zero")
            }
            if (!seenIdat) {
                throw PngFormatException(MissingIdat, chunk.offset, "PNG reached IEND before IDAT")
            }
            seenIend = true
        } else if (chunk.isType(PNG_CHUNK_PLTE)) {
            if (seenPalette) {
                throw PngFormatException(InvalidPalette, chunk.offset, "PNG contains more than one PLTE chunk")
            }
            if (seenTransparency) {
                throw PngFormatException(
                    InvalidTransparency,
                    chunk.offset,
                    "PLTE must precede tRNS"
                )
            }
            if (metadataBuilder.hasBackground()) {
                throw PngFormatException(
                    MetadataOutOfOrder,
                    chunk.offset,
                    "PLTE must precede bKGD"
                )
            }
            if (seenIdat) {
                throw PngFormatException(InvalidPalette, chunk.offset, "PLTE must appear before IDAT")
            }
            validatePaletteChunk(chunk, ihdr)
            palette = chunk.payload()
            seenPalette = true
        } else if (chunk.isType(PNG_CHUNK_tRNS)) {
            if (seenTransparency) {
                throw PngFormatException(
                    InvalidTransparency,
                    chunk.offset,
                    "PNG contains more than one tRNS chunk"
                )
            }
            if (seenIdat) {
                throw PngFormatException(
                    InvalidTransparency,
                    chunk.offset,
                    "tRNS must appear before IDAT"
                )
            }
            transparency = parsePngTransparencyChunk(chunk, ihdr, palette)
            seenTransparency = true
        } else if (metadataBuilder.handleChunk(chunk, ihdr, seenPalette, seenIdat, palette, limits)) {
            if (seenIdat) {
                idatEnded = true
            }
        } else {
            if (seenIdat) {
                idatEnded = true
            }
            let retained = metadataBuilder.retainUnknown(
                chunk,
                seenPalette,
                seenIdat,
                unknownPolicy
            )
            if (isCriticalChunk(chunk.chunkType()) && !retained) {
                throw PngFormatException(
                    UnsupportedCriticalChunk,
                    chunk.offset,
                    "PNG contains an unsupported critical chunk"
                )
            }
        }
    }

    if (session.remaining() != 0) {
        throw PngFormatException(TrailingData, session.position(), "PNG contains bytes after IEND")
    }

    let expectedSize = expectedInflatedSize(ihdr, limits)
    let inflated = inflatePngZlibExact(compressed.toArray(), expectedSize)
    let metadata = metadataBuilder.build(palette, transparency)
    PngDecodedRows(ihdr, metadata, decodeInflatedRows(inflated, ihdr))
}

public func decodePngNonInterlaced(bytes: Array<Byte>, limits: PngReadLimits): PngDecodedRows {
    decodePngNonInterlaced(bytes, limits, Discard)
}

public func decodePngNonInterlaced(
    bytes: Array<Byte>,
    unknownPolicy: PngUnknownChunkPolicy
): PngDecodedRows {
    decodePngNonInterlaced(bytes, PngReadLimits(), unknownPolicy)
}

public func decodePngNonInterlaced(bytes: Array<Byte>): PngDecodedRows {
    decodePngNonInterlaced(bytes, PngReadLimits(), Discard)
}
