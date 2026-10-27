# PDFBox Android's optional JPX image codec is absent by design.
# Living Memory extracts text only and provides no PDF image rendering/OCR.
# Upstream JPXFilter checks Class.forName and handles ClassNotFoundException.
# Do not hide any other missing dependency or disable R8.
-dontwarn com.gemalto.jp2.JP2Decoder
