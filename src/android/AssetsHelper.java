package cordova.plugin.Assets;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.app.Activity;
import android.database.Cursor;
import android.provider.MediaStore;
import android.provider.MediaStore.Images;

/**
 * This class echoes a string called from JavaScript.
 */
public class AssetsHelper extends CordovaPlugin {

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equals("getAllPhotos")) {
                    this.getAllPhotos(callbackContext);
                    return true;
        }

        return false;
    }
    private void getAllPhotos(CallbackContext callbackContext) {
              Cursor mCursor = cordova.getActivity().getContentResolver().query(Images.Media.EXTERNAL_CONTENT_URI, null,
                      null,
                      null, null);
              if(mCursor==null)
              {
                    callbackContext.error("error mCursor is null");
                    return;
              }

              	JSONArray arr = new JSONArray();
              	JSONObject jsonObject;
              		String path;
              		String name;
              		String size;
              		String id;
              		while (mCursor.moveToNext()) {
              		    jsonObject = new JSONObject();
              			path = mCursor.getString(mCursor
              					.getColumnIndex(MediaStore.Images.Media.DATA));
              			name = mCursor.getString(mCursor
              					.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME));
              		    size = mCursor.getString(mCursor.getColumnIndex(MediaStore.Images.Media.SIZE));
              		    id = mCursor.getString(mCursor.getColumnIndex(MediaStore.Images.Media._ID));
              			try {
                                jsonObject.put("filename", name);
                                jsonObject.put("localpath", path);
                                jsonObject.put("size", size);
                                jsonObject.put("url", id);
                            } catch (JSONException e) {
                                e.printStackTrace();
                            }
              			arr.put(jsonObject);
              		}
            callbackContext.success(arr);
    }
}
