# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'SleepWell' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  # 友盟公共组件，必须添加
  pod 'UMCommon'

  # 友盟统计 SDK (可选，按需添加)
  pod 'UMDevice'      # 设备信息组件，统计SDK依赖，必须添加
  pod 'UMAPM'         # U-APM 产品包
  # pod 'UMAnalytics'   # 老版本统计，新版本推荐 U-App (下面)
  # pod 'UMCCommonLog'  # 日志库，统计SDK依赖，必须添加

  # U-App 行为分析 (可选，按需添加)
  pod 'UMCommonLog'   # U-App依赖组件
 # pod 'UMAnalyticsOpenCDP' # U-App SDK

  # Pods for SleepWell

  target 'SleepWellTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'SleepWellUITests' do
    # Pods for testing
  end

end
