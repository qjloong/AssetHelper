var exec = require('cordova/exec');

var AssetsHelper = {

    getAllPhotos:function(successCallback, errorCallback) {
        exec(successCallback, errorCallback, "AssetsHelper", "getAllPhotos", []);
    },

    getThumbnails:function(urlList, successCallback, errorCallback) {
        exec(successCallback, errorCallback, "AssetsHelper", "getThumbnails", [urlList]);
    },

    exportAsset:function(assetInfo, successCallback, errorCallback) {
        exec(successCallback, errorCallback, "AssetsHelper", "exportAsset", [assetInfo]);
    },

    savePhoto:function(filePath, successCallback, errorCallback) {
        exec(successCallback, errorCallback, "AssetsHelper", "savePhoto", [filePath]);
    }
}

module.exports = AssetsHelper;