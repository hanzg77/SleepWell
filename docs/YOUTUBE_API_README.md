# YouTube API v3 搜索服务

这个服务提供了基于YouTube API v3的完整视频搜索和管理功能，客户端可以通过服务器中转来搜索YouTube视频、获取热门内容、浏览分类等。

## 🚀 功能特性

- 🔍 **智能搜索**: 支持关键词搜索、多维度过滤和排序
- 🔥 **热门视频**: 获取各地区热门视频内容
- 📂 **分类浏览**: 按视频分类浏览内容
- 💡 **搜索建议**: 智能搜索建议功能
- 📄 **分页支持**: 完整的分页功能
- 📊 **数据统计**: 详细的视频统计信息
- 📱 **响应式设计**: 支持移动端和桌面端
- 🔧 **错误处理**: 完善的错误处理和重试机制

## 环境配置

### 1. 环境变量配置

在 `.env` 文件中添加以下配置：

```env
# YouTube API配置
YOUTUBE_API_KEY=your_youtube_api_key_here

# 服务配置
API_PORT=8000
MONGODB_URI=mongodb://localhost:27017/sleepwell
```

### 2. 获取YouTube API Key

1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 创建新项目或选择现有项目
3. 启用 YouTube Data API v3
4. 创建凭据（API Key）
5. 配置 API Key 限制（推荐）
6. 将API Key添加到环境变量中

### 3. API Key 安全配置

在 Google Cloud Console 中：
- 设置 API Key 限制为仅允许 YouTube Data API v3
- 配置 HTTP 引用站点限制
- 设置配额限制和监控

## API接口

### 1. 搜索YouTube视频

**接口**: `GET /api/youtube/search`

**功能**: 搜索YouTube视频，支持多种过滤和排序选项

**参数**:
- `q` (必需): 搜索关键词
- `max_results` (可选): 最大结果数量，默认20，最大50
- `order` (可选): 排序方式，默认"relevance"
  - `date`: 按上传时间排序
  - `rating`: 按评分排序
  - `relevance`: 按相关度排序
  - `title`: 按标题排序
  - `viewCount`: 按观看次数排序
- `language` (可选): 语言代码，默认"zh"
- `region_code` (可选): 地区代码，默认"US"
- `video_duration` (可选): 视频时长过滤
  - `short`: 短视频 (< 4分钟)
  - `medium`: 中等视频 (4-20分钟)
  - `long`: 长视频 (> 20分钟)
- `video_definition` (可选): 视频质量过滤
  - `high`: 高清视频
  - `standard`: 标清视频
- `video_embeddable` (可选): 是否可嵌入 (true/false)
- `video_license` (可选): 视频许可证
  - `creativeCommon`: 创作共用许可
  - `youtube`: YouTube标准许可
- `video_syndicated` (可选): 是否可分发 (true/false)
- `video_type` (可选): 视频类型
  - `any`: 任何类型
  - `episode`: 剧集
  - `movie`: 电影
- `page_token` (可选): 分页令牌，用于获取下一页结果

**示例请求**:
```bash
# 基本搜索
curl "http://localhost:8000/api/youtube/search?q=relaxing%20music&max_results=10"

# 高级搜索
curl "http://localhost:8000/api/youtube/search?q=轻音乐&max_results=20&order=viewCount&video_duration=medium&region_code=CN"

# 分页搜索
curl "http://localhost:8000/api/youtube/search?q=白噪音&page_token=CAEQAA"
```

**响应示例**:
```json
{
  "success": true,
  "message": "YouTube search completed successfully",
  "data": {
    "kind": "youtube#searchListResponse",
    "etag": "RCVNEMaTsIHcZ-9mhIalVMhE6e0",
    "nextPageToken": "CAEQAA",
    "prevPageToken": "CAIQAQ",
    "regionCode": "US",
    "pageInfo": {
      "totalResults": 1000000,
      "resultsPerPage": 20
    },
    "items": [
      {
        "videoId": "dQw4w9WgXcQ",
        "title": "视频标题",
        "description": "视频描述",
        "thumbnail": {
          "default": "https://i.ytimg.com/vi/dQw4w9WgXcQ/default.jpg",
          "medium": "https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg",
          "high": "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
          "standard": "https://i.ytimg.com/vi/dQw4w9WgXcQ/sddefault.jpg",
          "maxres": "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg"
        },
        "channelTitle": "频道名称",
        "channelId": "UCJkMa25_J1Ve...",
        "publishedAt": "2023-01-01T00:00:00Z",
        "tags": ["标签1", "标签2"],
        "categoryId": "10",
        "liveBroadcastContent": "none",
        "defaultLanguage": "zh",
        "defaultAudioLanguage": "zh"
      }
    ]
  }
}
```

### 2. 获取视频详细信息

**接口**: `GET /api/youtube/videos`

**功能**: 获取一个或多个视频的详细信息，包括统计数据

**参数**:
- `video_ids` (必需): 视频ID列表，用逗号分隔，最多50个

**示例请求**:
```bash
curl "http://localhost:8000/api/youtube/videos?video_ids=dQw4w9WgXcQ,abc123def456"
```

**响应示例**:
```json
{
  "success": true,
  "message": "Video details retrieved successfully",
  "data": {
    "kind": "youtube#videoListResponse",
    "etag": "hYwbHiEbEDu4FW13p_cU9jYlVJ0",
    "pageInfo": {
      "totalResults": 2,
      "resultsPerPage": 2
    },
    "items": [
      {
        "id": "dQw4w9WgXcQ",
        "snippet": {
          "title": "视频标题",
          "description": "视频描述",
          "thumbnails": {
            "default": {"url": "https://...", "width": 120, "height": 90},
            "medium": {"url": "https://...", "width": 320, "height": 180},
            "high": {"url": "https://...", "width": 480, "height": 360}
          },
          "channelTitle": "频道名称",
          "channelId": "UC...",
          "publishedAt": "2023-01-01T00:00:00Z",
          "tags": ["标签1", "标签2"],
          "categoryId": "10"
        },
        "statistics": {
          "viewCount": "1000000",
          "likeCount": "50000",
          "commentCount": "1000",
          "favoriteCount": "0",
          "dislikeCount": "100"
        },
        "contentDetails": {
          "duration": "PT4M13S",
          "dimension": "1920x1080",
          "definition": "hd",
          "caption": "false",
          "licensedContent": true,
          "contentRating": {},
          "projection": "rectangular"
        }
      }
    ]
  }
}
```

### 3. 获取频道信息

**接口**: `GET /api/youtube/channels`

**功能**: 获取YouTube频道的详细信息

**参数**:
- `channel_id` (必需): 频道ID

**示例请求**:
```bash
curl "http://localhost:8000/api/youtube/channels?channel_id=UCJkMa25_J1Ve..."
```

**响应示例**:
```json
{
  "success": true,
  "message": "Channel information retrieved successfully",
  "data": {
    "kind": "youtube#channelListResponse",
    "etag": "...",
    "pageInfo": {
      "totalResults": 1,
      "resultsPerPage": 1
    },
    "items": [
      {
        "id": "UCJkMa25_J1Ve...",
        "snippet": {
          "title": "频道名称",
          "description": "频道描述",
          "customUrl": "@channelname",
          "publishedAt": "2020-01-01T00:00:00Z",
          "thumbnails": {
            "default": {"url": "https://...", "width": 88, "height": 88},
            "medium": {"url": "https://...", "width": 240, "height": 240},
            "high": {"url": "https://...", "width": 800, "height": 800}
          },
          "country": "US",
          "defaultLanguage": "en"
        },
        "statistics": {
          "viewCount": "10000000",
          "subscriberCount": "100000",
          "hiddenSubscriberCount": false,
          "videoCount": "500"
        },
        "brandingSettings": {
          "channel": {
            "title": "频道名称",
            "description": "频道描述",
            "keywords": "关键词1,关键词2",
            "defaultTab": "featured",
            "trackingAnalyticsAccountId": "UA-12345678-1",
            "moderateComments": false,
            "showRelatedChannels": true,
            "showBrowseView": true,
            "featuredChannelsTitle": "推荐频道",
            "featuredChannelsUrls": ["UC...", "UC..."]
          }
        }
      }
    ]
  }
}
```

### 4. 获取热门视频

**接口**: `GET /api/youtube/trending`

**功能**: 获取指定地区的热门视频列表

**参数**:
- `region_code` (可选): 地区代码，默认"US"
- `category_id` (可选): 分类ID，用于过滤特定分类的热门视频
- `max_results` (可选): 最大结果数量，默认20，最大50

**示例请求**:
```bash
# 获取美国热门视频
curl "http://localhost:8000/api/youtube/trending?region_code=US&max_results=20"

# 获取音乐分类热门视频
curl "http://localhost:8000/api/youtube/trending?region_code=US&category_id=10&max_results=10"
```

**响应示例**:
```json
{
  "success": true,
  "message": "Trending videos retrieved successfully",
  "data": {
    "kind": "youtube#videoListResponse",
    "etag": "...",
    "pageInfo": {
      "totalResults": 20,
      "resultsPerPage": 20
    },
    "items": [
      {
        "videoId": "abc123def456",
        "title": "热门视频标题",
        "description": "视频描述",
        "thumbnail": {
          "default": "https://...",
          "medium": "https://...",
          "high": "https://...",
          "standard": "https://...",
          "maxres": "https://..."
        },
        "channelTitle": "频道名称",
        "channelId": "UC...",
        "publishedAt": "2023-01-01T00:00:00Z",
        "tags": ["标签1", "标签2"],
        "categoryId": "10",
        "statistics": {
          "viewCount": "5000000",
          "likeCount": "250000",
          "commentCount": "5000"
        }
      }
    ]
  }
}
```

### 5. 获取视频分类

**接口**: `GET /api/youtube/categories`

**功能**: 获取指定地区的视频分类列表

**参数**:
- `region_code` (可选): 地区代码，默认"US"

**示例请求**:
```bash
curl "http://localhost:8000/api/youtube/categories?region_code=US"
```

**响应示例**:
```json
{
  "success": true,
  "message": "Video categories retrieved successfully",
  "data": {
    "kind": "youtube#videoCategoryListResponse",
    "etag": "...",
    "pageInfo": {
      "totalResults": 16,
      "resultsPerPage": 16
    },
    "items": [
      {
        "id": "1",
        "snippet": {
          "title": "电影和动画",
          "assignable": true,
          "channelId": "UCBR8-60-B28hp2BmDPdntcQ"
        }
      },
      {
        "id": "10",
        "snippet": {
          "title": "音乐",
          "assignable": true,
          "channelId": "UCBR8-60-B28hp2BmDPdntcQ"
        }
      }
    ]
  }
}
```

### 6. 获取搜索建议

**接口**: `GET /api/youtube/search/suggestions`

**功能**: 基于关键词获取搜索建议

**参数**:
- `q` (必需): 搜索关键词前缀

**示例请求**:
```bash
curl "http://localhost:8000/api/youtube/search/suggestions?q=relaxing"
```

**响应示例**:
```json
{
  "success": true,
  "message": "Search suggestions retrieved successfully",
  "data": {
    "query": "relaxing",
    "suggestions": [
      "relaxing music",
      "relaxing sounds",
      "relaxing meditation",
      "relaxing piano music",
      "relaxing nature sounds"
    ]
  }
}
```

## 前端界面

### 基础搜索界面

文件: `youtube_search_frontend.html`

**特性**:
- 简洁的搜索界面
- 基本过滤功能
- 分页支持
- 响应式设计
- 视频卡片展示

**使用方法**:
1. 将文件放在静态文件目录中
2. 访问 `http://localhost:8000/youtube_search_frontend.html`

### 高级搜索界面

文件: `youtube_search_advanced.html`

**特性**:
- 多标签页设计（搜索、热门、分类）
- 智能搜索建议
- 高级过滤和排序
- 统计信息显示
- 完整的用户体验

**使用方法**:
1. 将文件放在静态文件目录中
2. 访问 `http://localhost:8000/youtube_search_advanced.html`

## 使用示例

### JavaScript/TypeScript 客户端

```javascript
// 搜索视频
async function searchYouTubeVideos(query, maxResults = 20) {
  const response = await fetch(`/api/youtube/search?q=${encodeURIComponent(query)}&max_results=${maxResults}`);
  const data = await response.json();
  
  if (data.success) {
    return data.data.items;
  } else {
    throw new Error(data.message);
  }
}

// 获取视频详情
async function getVideoDetails(videoIds) {
  const response = await fetch(`/api/youtube/videos?video_ids=${videoIds.join(',')}`);
  const data = await response.json();
  
  if (data.success) {
    return data.data.items;
  } else {
    throw new Error(data.message);
  }
}

// 获取热门视频
async function getTrendingVideos(regionCode = 'US', maxResults = 20) {
  const response = await fetch(`/api/youtube/trending?region_code=${regionCode}&max_results=${maxResults}`);
  const data = await response.json();
  
  if (data.success) {
    return data.data.items;
  } else {
    throw new Error(data.message);
  }
}

// 获取搜索建议
async function getSearchSuggestions(query) {
  const response = await fetch(`/api/youtube/search/suggestions?q=${encodeURIComponent(query)}`);
  const data = await response.json();
  
  if (data.success) {
    return data.data.suggestions;
  } else {
    return [];
  }
}

// 分页搜索示例
async function searchWithPagination(query, pageToken = null) {
  const params = new URLSearchParams({
    q: query,
    max_results: 20
  });
  
  if (pageToken) {
    params.append('page_token', pageToken);
  }
  
  const response = await fetch(`/api/youtube/search?${params}`);
  const data = await response.json();
  
  if (data.success) {
    return {
      items: data.data.items,
      nextPageToken: data.data.nextPageToken,
      prevPageToken: data.data.prevPageToken,
      totalResults: data.data.pageInfo.totalResults
    };
  } else {
    throw new Error(data.message);
  }
}

// 使用示例
searchYouTubeVideos('relaxing music', 10)
  .then(videos => {
    console.log('搜索结果:', videos);
  })
  .catch(error => {
    console.error('搜索失败:', error);
  });

// 分页搜索示例
async function loadMoreResults(query) {
  let pageToken = null;
  let allVideos = [];
  
  do {
    const result = await searchWithPagination(query, pageToken);
    allVideos = allVideos.concat(result.items);
    pageToken = result.nextPageToken;
  } while (pageToken && allVideos.length < 100);
  
  return allVideos;
}
```

### Python 客户端

```python
import requests
import json

class YouTubeAPI:
    def __init__(self, base_url="http://localhost:8000"):
        self.base_url = base_url
    
    def search_videos(self, query, max_results=20, **kwargs):
        """搜索YouTube视频"""
        url = f"{self.base_url}/api/youtube/search"
        params = {
            "q": query,
            "max_results": max_results,
            **kwargs
        }
        
        response = requests.get(url, params=params)
        data = response.json()
        
        if data["success"]:
            return data["data"]["items"]
        else:
            raise Exception(data["message"])
    
    def get_video_details(self, video_ids):
        """获取视频详情"""
        url = f"{self.base_url}/api/youtube/videos"
        params = {
            "video_ids": ",".join(video_ids) if isinstance(video_ids, list) else video_ids
        }
        
        response = requests.get(url, params=params)
        data = response.json()
        
        if data["success"]:
            return data["data"]["items"]
        else:
            raise Exception(data["message"])
    
    def get_trending_videos(self, region_code="US", max_results=20, category_id=None):
        """获取热门视频"""
        url = f"{self.base_url}/api/youtube/trending"
        params = {
            "region_code": region_code,
            "max_results": max_results
        }
        
        if category_id:
            params["category_id"] = category_id
        
        response = requests.get(url, params=params)
        data = response.json()
        
        if data["success"]:
            return data["data"]["items"]
        else:
            raise Exception(data["message"])
    
    def get_categories(self, region_code="US"):
        """获取视频分类"""
        url = f"{self.base_url}/api/youtube/categories"
        params = {"region_code": region_code}
        
        response = requests.get(url, params=params)
        data = response.json()
        
        if data["success"]:
            return data["data"]["items"]
        else:
            raise Exception(data["message"])
    
    def get_search_suggestions(self, query):
        """获取搜索建议"""
        url = f"{self.base_url}/api/youtube/search/suggestions"
        params = {"q": query}
        
        response = requests.get(url, params=params)
        data = response.json()
        
        if data["success"]:
            return data["data"]["suggestions"]
        else:
            return []

# 使用示例
api = YouTubeAPI()

try:
    # 搜索视频
    videos = api.search_videos("relaxing music", max_results=10, order="viewCount")
    print(f"找到 {len(videos)} 个视频")
    
    # 获取热门视频
    trending = api.get_trending_videos("US", max_results=5)
    print(f"热门视频: {len(trending)} 个")
    
    # 获取搜索建议
    suggestions = api.get_search_suggestions("relaxing")
    print(f"搜索建议: {suggestions}")
    
except Exception as e:
    print(f"错误: {e}")
```

### cURL 示例

```bash
# 基本搜索
curl "http://localhost:8000/api/youtube/search?q=relaxing%20music&max_results=5"

# 高级搜索
curl "http://localhost:8000/api/youtube/search?q=轻音乐&order=viewCount&video_duration=medium&region_code=CN"

# 获取视频详情
curl "http://localhost:8000/api/youtube/videos?video_ids=dQw4w9WgXcQ,abc123def456"

# 获取热门视频
curl "http://localhost:8000/api/youtube/trending?region_code=US&max_results=10"

# 获取分类
curl "http://localhost:8000/api/youtube/categories?region_code=US"

# 获取搜索建议
curl "http://localhost:8000/api/youtube/search/suggestions?q=relaxing"
```

## 错误处理

### 常见错误码

- `400`: 请求参数错误
- `401`: API Key 无效或未授权
- `403`: API Key 配额已用完
- `404`: 资源未找到
- `500`: 服务器内部错误或YouTube API错误

### 错误响应格式

```json
{
  "success": false,
  "message": "错误描述",
  "data": null
}
```

### 错误处理示例

```javascript
async function safeSearch(query) {
  try {
    const response = await fetch(`/api/youtube/search?q=${encodeURIComponent(query)}`);
    const data = await response.json();
    
    if (data.success) {
      return data.data;
    } else {
      // 处理业务错误
      console.error('搜索失败:', data.message);
      return null;
    }
  } catch (error) {
    // 处理网络错误
    console.error('网络错误:', error);
    return null;
  }
}
```

## 性能优化

### 1. 请求优化

- 使用分页减少单次请求数据量
- 批量获取视频详情
- 实现请求缓存
- 使用适当的超时设置

### 2. 客户端优化

- 实现防抖搜索
- 图片懒加载
- 虚拟滚动
- 本地缓存

### 3. 服务器优化

- 实现 Redis 缓存
- 请求去重
- 连接池管理
- 监控和日志

## 注意事项

1. **API配额限制**: YouTube API有每日配额限制，请注意使用频率
2. **错误处理**: 服务会返回详细的错误信息，客户端应该妥善处理
3. **缓存**: 建议在客户端实现缓存机制，避免重复请求
4. **安全性**: API Key应该妥善保管，不要暴露在客户端代码中
5. **合规性**: 请遵守YouTube API的使用条款和内容政策

## 部署

### 1. 本地开发

```bash
# 安装依赖
pip install -r requirements.api.txt

# 启动服务
python main.py

# 或使用 uvicorn
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. Docker 部署

```bash
# 构建镜像
docker-compose build --no-cache

# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f api
```

### 3. 生产环境

- 使用反向代理（Nginx）
- 配置 SSL 证书
- 设置环境变量
- 监控和日志
- 备份和恢复

## 监控和日志

### 1. 日志级别

- `INFO`: 正常操作日志
- `WARNING`: 警告信息
- `ERROR`: 错误信息
- `DEBUG`: 调试信息

### 2. 监控指标

- API 调用次数
- 响应时间
- 错误率
- 配额使用情况

### 3. 健康检查

```bash
# 健康检查接口
curl "http://localhost:8000/health"

# 预期响应
{"status": "healthy"}
```

## 联系支持

如果遇到问题，请提供：
1. 错误日志
2. 请求参数
3. 环境信息
4. 复现步骤

---

**注意**: 请遵守 YouTube API 的使用条款和配额限制。定期检查 API 配额使用情况，避免超出限制。 