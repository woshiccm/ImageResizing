图像是每个应用程序不可缺少的一部分。调整图像大小是所有开发人员经常遇到的问题。iOS有5中图片缩略技术，但是我们应该在项目中选择哪种技术呢？尤其是面对高精度图片的缩略时，方式不当可能会出现OOM。现在我们开始一一去看看这5中图片缩略技术吧。


# UIKit

**UIGraphicsBeginImageContextWithOptions & UIImage -drawInRect:**

用于图像大小调整的最高级API可以在UIKit框架中找到。给定一个UIImage，可以使用临时图形上下文来渲染缩放版本。这种方式最简单，效果也不错，但我不太建议使用这种方式，至于原因会在最后讲到。

```
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
}
```

# CoreGraphics  

**CGBitmapContextCreate & CGContextDrawImage** 

CoreGraphics / Quartz 2D提供了一套较低级别的API，允许进行更高级的配置。 给定一个CGImage，使用临时位图上下文来渲染缩放后的图像。
使用CoreGraphics图像的质量与UIKit图像相同。 至少我无法察觉到任何区别，并且imagediff也没有任何区别。 表演只有不同之处。

```
extension UIImage {
    
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
}


```

![1_2I79bGukRv5wlirgNQKU7Q.gif](https://upload-images.jianshu.io/upload_images/2086987-70c7b378593fd825.gif?imageMogr2/auto-orient/strip)

让我们看看CoreGraphics图片和原始图片之间的差异。如果仔细观察GIF，可以注意到图像模糊。 


# ImageIO    

**CGImageSourceCreateThumbnailAtIndex**

Image I / O是一个功能强大但鲜为人知的用于处理图像的框架。 独立于Core Graphics，它可以在许多不同格式之间读取和写入，访问照片元数据以及执行常见的图像处理操作。 这个库提供了该平台上最快的图像编码器和解码器，具有先进的缓存机制，甚至可以逐步加载图像。

```
extension UIImage {
    
    //ImageIO
    func resizeIO(size:CGSize) -> UIImage? {
        
        guard let data = UIImagePNGRepresentation(self) else { return nil }
        
        let maxPixelSize = max(size.width, size.height)
        
        //let imageSource = CGImageSourceCreateWithURL(url, nil)
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
}

```


# CoreImage
CoreImage是IOS5中新加入的一个Objective-c的框架，里面提供了强大高效的图像处理功能，用来对基于像素的图像进行操作与分析。IOS提供了很多强大的滤镜(Filter)，这些Filter提供了各种各样的效果，并且还可以通过滤镜链将各种效果的Filter叠加起来，形成强大的自定义效果，如果你对该效果不满意，还可以子类化滤镜。

```
extension UIImage {
    
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
}

```  

![1_k1lG_E212_X_Y8Kq0uaEng.gif](https://upload-images.jianshu.io/upload_images/2086987-24725b14f75d59b2.gif?imageMogr2/auto-orient/strip)   
可以注意到灯光看起来比它应该更亮。 这个伪像出现在用CoreImage调整大小的所有图像中。 一般来说，图像看起来更清晰一些。

# vImage 
vImage可能是这几种技术中被了解最少的，使用时需要 **import Accelerate**

使用CPU的矢量处理器处理大图像。 强大的图像处理功能，包括Core Graphics和Core Video互操作，格式转换和图像处理。
  

```
extension UIImage {
    
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

```

这个不是很流行并且文档很少的小框架却十分强大。 结果令人惊讶。这样可以产生最佳效果，并且图像清晰平衡。 没有CG那么模糊，又不像CI那样明亮的不自然。

以下是引用自方苹果官方文档
>Lanczos重采样方法通常比简单的方法（如线性插值）产生更好的结果。 但是，Lanczos方法会在高频信号的区域（例如线条艺术）附近产生振铃效应。

# 5种技术表现对比  

测试设备是系统为iOS8.4的iPhone6

### JPEG
加载，缩放和显示的大尺寸高分辨率图片来自[NASA Visible Earth](https://visibleearth.nasa.gov/view.php?id=78314)，原图（12000×12000像素，20 MB JPEG），缩放尺寸为1/10：

![Screen Shot 2018-06-23 at 6.25.18 PM.png](https://upload-images.jianshu.io/upload_images/2086987-2bd17bae458fe9cb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240) 


### PNG
 图片来自[Postgres.app](https://postgresapp.com/) Icon，原图(1024 ⨉ 1024 px 1MB PNG)，缩放尺寸为1/10：
![Screen Shot 2018-06-23 at 6.25.30 PM.png](https://upload-images.jianshu.io/upload_images/2086987-672daeaaa893f24c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


通过上面测试可以看到Core Image表现最差。Core Graphics 和 Image I/O最好。实际上，在苹果官方在[ Performance Best Practices section of the Core Image Programming Guide ](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_performance/ci_performance.html#//apple_ref/doc/uid/TP30001185-CH10-SW1)部分中特别推荐使用Core Graphics或Image I / O功能预先裁剪或缩小图像。


其实微信最早是使用UIKit，后来改使用ImageIO。
>UIKit处理大分辨率图片时，往往容易出现OOM，原因是-[UIImage drawInRect:]在绘制时，先解码图片，再生成原始分辨率大小的bitmap，这是很耗内存的。解决方法是使用更低层的ImageIO接口，避免中间bitmap产生。 

所以最后我比较建议和微信一样使用ImageIO。
 
**以上所有测试资料均来自以下参考文章**

参考文章：   
[Resize Image with Swift 4](https://medium.com/@nishantnitb/resize-image-with-swift-4-ca17d65bbc85)   
[Image Resizing Techniques](http://nshipster.com/image-resizing/)   
[Resizing Techniques and Image Quality That Every iOS Developer Should Know](https://medium.com/ymedialabs-innovation/resizing-techniques-and-image-quality-that-every-ios-developer-should-know-e061f33f7aba)




