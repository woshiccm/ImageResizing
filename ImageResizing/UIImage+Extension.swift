//
//  UIImage+Extension.swift
//  ImageResizing
//
//  Created by roy.cao on 2018/6/23.
//  Copyright © 2018 roy.cao. All rights reserved.
//

import Foundation
import UIKit
import Accelerate

extension UIImage {
    
    //UIKit
    func resizeUI(size: CGSize) -> UIImage? {
        
        let hasAlpha = false
        let scale: CGFloat = 0.0 // Automatically use scale factor of main screen
        
        /**
         创建一个图片类型的上下文。调用UIGraphicsBeginImageContextWithOptions函数就可获得用来处理图片的图形上下文。利用该上下文，你就可以在其上进行绘图，并生成图片
         
         size：表示所要创建的图片的尺寸
         opaque：表示这个图层是否完全透明，如果图形完全不用透明最好设置为YES以优化位图的存储，这样可以让图层在渲染的时候效率更高
         scale：指定生成图片的缩放因子，这个缩放因子与UIImage的scale属性所指的含义是一致的。传入0则表示让图片的缩放因子根据屏幕的分辨率而变化，所以我们得到的图片不管是在单分辨率还是视网膜屏上看起来都会很好
         */
        UIGraphicsBeginImageContextWithOptions(size, !hasAlpha, scale)
        self.draw(in: CGRect(origin: .zero, size: size))
        
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage!
    }
    
    //CoreGraphics
    func resizeCG(size:CGSize) -> UIImage? {
        
        guard  let cgImage = self.cgImage else { return nil }
        
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        let colorSpace = cgImage.colorSpace
        let bitmapInfo = cgImage.bitmapInfo
        
        guard let context = CGContext(data: nil,
                                      width: Int(size.width),
                                      height: Int(size.height),
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace!,
                                      bitmapInfo: bitmapInfo.rawValue) else {
            return nil
        }
        
        context.interpolationQuality = .high
        
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        
        let resizedImage = context.makeImage().flatMap {
            UIImage(cgImage: $0)
        }
        return resizedImage
    }
    
    //ImageIO
    func resizeIO(size:CGSize) -> UIImage? {
        
        guard let data = UIImagePNGRepresentation(self) else { return nil }
        
        let maxPixelSize = max(size.width, size.height)
        
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        
        //kCGImageSourceThumbnailMaxPixelSize为生成缩略图的大小。当设置为800，如果图片本身大于800*600，则生成后图片大小为800*600，如果源图片为700*500，则生成图片为800*500
        let options: [NSString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true
        ]
        
        let resizedImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary).flatMap{
            UIImage(cgImage: $0)
        }
        return resizedImage
    }
    
    //CoreImage
    func resizeCI(size:CGSize) -> UIImage? {
        
        guard  let cgImage = self.cgImage else { return nil }
        
        let scale = (Double)(size.width) / (Double)(self.size.width)
        
        let image = CIImage(cgImage: cgImage)
        
        let filter = CIFilter(name: "CILanczosScaleTransform")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(NSNumber(value:scale), forKey: kCIInputScaleKey)
        filter.setValue(1.0, forKey:kCIInputAspectRatioKey)
        
        guard let outputImage = filter.value(forKey: kCIOutputImageKey) as? CIImage else { return nil}
        
        let context = CIContext(options: [kCIContextUseSoftwareRenderer: false])
        
        let resizedImage = context.createCGImage(outputImage, from: outputImage.extent).flatMap {
            UIImage(cgImage: $0)
        }
        return resizedImage
    }
    
    //vImage
    func resizeVI(size:CGSize) -> UIImage? {
        
        guard  let cgImage = self.cgImage else { return nil }
        
        var format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: nil,
                                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                                          version: 0, decode: nil, renderingIntent: .defaultIntent)
        
        var sourceBuffer = vImage_Buffer()
        defer {
            free(sourceBuffer.data)
        }
        
        var error = vImageBuffer_InitWithCGImage(&sourceBuffer, &format, nil, cgImage, numericCast(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }
        
        // create a destination buffer
        let scale = self.scale
        let destWidth = Int(size.width)
        let destHeight = Int(size.height)
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let destBytesPerRow = destWidth * bytesPerPixel
        
        let destData = UnsafeMutablePointer<UInt8>.allocate(capacity: destHeight * destBytesPerRow)
        defer {
            destData.deallocate(capacity: destHeight * destBytesPerRow)
        }
        var destBuffer = vImage_Buffer(data: destData, height: vImagePixelCount(destHeight), width: vImagePixelCount(destWidth), rowBytes: destBytesPerRow)
        
        // scale the image
        error = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil, numericCast(kvImageHighQualityResampling))
        guard error == kvImageNoError else { return nil }
        
        // create a CGImage from vImage_Buffer
        var destCGImage = vImageCreateCGImageFromBuffer(&destBuffer, &format, nil, nil, numericCast(kvImageNoFlags), &error)?.takeRetainedValue()
        guard error == kvImageNoError else { return nil }
        
        // create a UIImage
        let resizedImage = destCGImage.flatMap {
            UIImage(cgImage: $0, scale: 0.0, orientation: self.imageOrientation)
        }
        
        destCGImage = nil
        return resizedImage
    }
}

//ImageIO
func resizeIO(url: URL, size:CGSize) -> UIImage? {
    
    let maxPixelSize = max(size.width, size.height)
    
    let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil)
    
    //kCGImageSourceThumbnailMaxPixelSize为生成缩略图的大小。当设置为800，如果图片本身大于800*600，则生成后图片大小为800*600，如果源图片为700*500，则生成图片为800*500
    let options: [NSString: Any] = [
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        kCGImageSourceCreateThumbnailFromImageAlways: true
    ]
    
    let resizedImage = CGImageSourceCreateImageAtIndex(imageSource!, 0, options as CFDictionary).flatMap{
        UIImage(cgImage: $0)
    }
    return resizedImage
}





