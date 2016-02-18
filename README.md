# AssetHelper
    ios AssetHelper for cordova

    使用方法
    cordova plugin add git@github.com:qjloong/AssetHelper.git

    example

        //iOS获取相册全部资源
        function getAssetsMetaInfo() {
            navigator.AssetsHelper.getAllPhotos(function (res) {
                $$console.log("Assets  --------", res);
            }, function (err) {
                $$console.log("exportAsset  --------", err);
            });
        }
        //iOS 导出相册资源到沙盒
        function exportFile(assetInfo) {
            navigator.AssetsHelper.exportAsset(assetInfo, function (res) {
                $$console.log("exportAsset  --------", res);
            }, function (err) {
            });
        }
