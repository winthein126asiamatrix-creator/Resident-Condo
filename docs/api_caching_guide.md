# API Caching နှင့် Offline Read လမ်းညွှန်

## 1. Architecture Overview (အဆောက်အအုံ ခြုံငုံ)

Cache သည် widget များနှင့် တိုက်ရိုက်ချိတ်ဆက်ထားခြင်း မရှိသည့် သီးခြား Drift/SQLite အဆင့်တစ်ခု ဖြစ်သည်။

```mermaid
flowchart LR
  UI[Flutter UI] --> Controller[GetX Controller]
  Controller --> UseCase[UseCase]
  UseCase --> Repository[Feature Repository]
  Repository -->|online, success| Remote[Dio Data Source]
  Remote --> ApiService[DioApiService]
  ApiService --> Api[Backend API]
  Repository -->|save/refresh| CacheStore[ApiCacheStore]
  CacheStore --> Database[AppCacheDatabase (Drift/SQLite)]
  Repository -->|offline or retryable GET failure| CacheStore
```

အသုံးပြုသည့် အဓိက class များ:

- `lib/core/network/api_binding.dart`: `ApiBinding` は `DioApiService` နှင့် `ApiCacheStore` ကို မှတ်ပုံတင်ပေးသည်။
- `lib/core/cache/api_cache_store.dart`: `ApiCacheStore` နှင့် `CachedApiEntry`။
- `lib/core/cache/app_cache_database.dart`: `AppCacheDatabase` နှင့် `CacheEntries`။
- Implementation နမူနာ: `lib/features/auth/data/repositories/auth_repository_impl.dart`။
- JSON model: `lib/features/auth/data/models/auth_user.dart`, `AuthUser.toJson()`။

## 2. `/auth/me` Caching မည်သို့ အလုပ်လုပ်သည်

Endpoint သည် `GET /auth/me` ဖြစ်ပြီး `AuthRemoteDataSource.updateMe()` မှတစ်ဆင့်ခေါ်ဆိုသည်။

`AuthRepositoryImpl.updateMe()` ၏ လုပ်ငန်းစဉ်:

1. Controller သို့မဟုတ် session restore path က `AuthUseCases.updateMe()` -> `AuthRepositoryImpl.updateMe()` ကို ခေါ်သည်။
2. `updateMe()` က `_remote.updateMe()` ကို `DioApiService` ဖြင့် ခေါ်သည်။
3. အောင်မြင်လျှင် SQLite သို့ ရေးသည်:
   - cache key: `auth.me`
   - account key: backend ကပြန်သော user id ကို string အဖြစ် သိမ်းသည်။
   - payload: `jsonEncode(user.toJson())`
   - TTL: 30 မိနစ်
4. Network/transport-level retryable failure ဖြစ်လျှင် `auth.me` ကို ဖတ်သည်။
   - Entry ရှိပြီး `CachedApiEntry.isFresh` မှန်လျှင် cache JSON ဖြင့် `AuthSession` ကို ပြန်ဖန်တီးသည်။
   - မဟုတ်လျှင်မူလ exception ကို ပြန် throw သည်။
5. 401/403 ကဲ့သို့ မ-retryable ဖြစ်သည့် အမှန်တကယ် ပယ်သံများတွင် exception ကို ပြန် throw သည်။
6. Sign in မတိုင်မီ ရှေး account ၏ data မပါရစေရန် cache row အားလုံးကို ဖျက်သည်။
7. Sign out လုပ်စဉ် token နှင့် local session များ ရှင်းပြီး cache row အားလုံးကို ဖျက်သည်။

အခြား scenario များ:

- Online: API အောင်မြင်လျှင် cache ကို ပြန် update လုပ်သည်။
- Offline: online request က retryable failure ဖြစ်ပြီး cache fresh ဖြစ်လျှင် cache ကို သုံးသည်။
- Cache လွတ်: row မရှိလျှင် exception ကို ပြန် throw သည်။
- Cache သက်တမ်းကုန်: `isFresh` false ဖြစ်လျှင် exception ကို ပြန် throw သည်။
- API error: non-retryable exception က cache ကို မထိနှင့် rethrow သည်။
- Logout: `_cache.clearAll()` ဖြင့် အားလုံးဖယ်ရှားသည်။

Cache profile က token valid မှုကို အထောက်အထားအဖြစ် မသုံးပါ။ Token validity ကို server ၏ `/auth/me` response, refresh interceptor, 401 handling များဖြင့်သာ အတည်ပြုသည်။

## 3. GET API တစ်ခု အတွက် Caching အသစ်ထည့်နည်း

JSON model ဖြင့် response လုပ်ပြီး offline read လိုချင်သော API များအတွက် အောက်ပါအတိုင်း လုပ်ပါ။

1. ပထမဆုံး existing code စစ်ဆေးပါ:
   - endpoint constant ကို `ApiEndPoints` မှာ ရှာပါ။
   - remote datasource နှင့် `DioApiService.get(...)` call ကို စစ်ပါ။
   - model class နှင့် parser ကို စစ်ပါ။
   - repository implementation နှင့် binding ကို စစ်ပါ။
   - `Rx` state ပြသသော controller ကို စစ်ပါ။
2. Model တွင် reversible JSON methods ထည့်ပါ:
   - `factory Model.fromJson(Map<String,dynamic>)`
   - `Map<String,dynamic> toJson()`
3. Deterministic cache key သတ်မှတ်ပါ:
   - endpoint name ပါဝင်ပါ။
   - authenticated account identity ရှိလျှင် `userId` ပါဝင်ပါ။
   - query parameter များကို stable encoding ပါဝင်ပါ။
4. TTL ကို `Duration` အနေဖြင့် ရွေးပါ (ဥပမာ `const Duration(minutes: 15)`)။
5. Repository တွင် `ApiCacheStore? cacheStore` ကို inject ပါ။
   - Binding မှ `Get.find<ApiCacheStore>()` ပေးပါ။
6. Repository method ကို အောက်ပါပုံစံဖြင့် ရေးပါ:

```dart
Future<MyModel> getMyData({
  required String accountId,
  required String status,
}) async {
  final cacheKey = 'myFeature.data:$accountId:$status';

  try {
    final data = await _remote.getMyData(status: status);
    try {
      await _cache?.save(
        key: cacheKey,
        accountKey: accountId,
        payload: data.toJson(),
        ttl: const Duration(minutes: 15),
      );
    } on Object {
      // Caching သည် optional convenience ဖြစ်သည်။ API အောင်မြင်ရုံကို မပါဝင်ဖြစ်စေရပါ။
    }
    return data;
  } on ApiException catch (error) {
    if (!error.isRetryable) {
      rethrow;
    }
    final cached = await _cache?.read(cacheKey);
    if (cached == null || !cached.isFresh) {
      rethrow;
    }
    return MyModel.fromJson(jsonDecode(cached.payloadJson));
  }
}
```

7. Controller state ကို ပြသပါ:
   - `final data = Rxn<MyModel>();`
   - `final isLoading = false.obs;`
   - `final errorMessage = RxnString();`
   - `final lastUpdatedAt = Rxn<DateTime>();`
   - repository/cache ပြီးလျှင် `lastUpdatedAt` ကို သတ်မှတ်ပါ။
8. `accountKey` ကို consistent အဖြစ် သုံးပါ။
9. Mutation பின்பြီး invalidate လုပ်ပါ:
   - `await _cache?.invalidate('myFeature.data:$accountId:$status');`
   - သို့မဟုတ် `await _cache?.invalidatePrefix('myFeature.data:$accountId');`
10. Mutation များကို online-only အဖြစ် ထားပါ။ Offline တွင် POST/PUT/PATCH/DELETE ကို cache မှ မ replay ပါ။

## 4. Database Table အသစ်ထည့်နည်း

`CacheEntries` table တစ်ခုတည်းက JSON အဖြစ် မည်သည့် successful GET response ကိုမဆို သိမ်းနိုင်သည်။ သာမန် endpoint caching အတွက် အများအားဖြင့် table သစ် မလိုပါ။

Table သစ် လိုချင်သည့်အခြေအနေ:

- structured local querying, index, သို့မဟုတ် join လိုလျှင်
- individual row တစ်ခုကို first-class entity အဖြစ် သုံးလျှင်
- large relational offline read လိုလျှင်
- JSON document အပြည့်အစုံ မဟုတ်ဘဲ per-field update လုပ်လျှင်

လုပ်ရန်:

1. `lib/core/cache/app_cache_database.dart` တွင် table class အသစ်ထည့်ပါ။
2. `@DriftDatabase(tables: <Type>[CacheEntries, NewTable])` တွင် register ပါ။
3. `schemaVersion` ကို increment လုပ်ပါ။
4. `MigrationStrategy.onUpgrade` တွင် migration ထည့်ပါ (`migrator.addColumn`, `migrator.createTable`, သို့မဟုတ် safe ဖြစ်လျှင် `migrator.createAll()`)။
5. Command ဖြင့် generate ပါ:

```bash
flutter pub run build_runner build
```

generated code ဟောင်းနှင့် ပြဿနာ ရှိလျှင်:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

6. လိုအပ်လျှင် repository/store သို့မဟုတ် Drift DAO method ထည့်ပါ (`ApiCacheStore` နည်းတူ)။

## 5. Security နှင့် Correctness

- Access token, refresh token, password နှင့် အခြား secret များကို `TokenStorage`/`SecureTokenStorage` တွင်သာထားပြီး `AppCacheDatabase` တွင် မထိခိုက်ပါစေ။
- response အောင်မြင်မှသာ cache ပါ။ Write ကို try/catch ဖြင့် နောက်က发展理念? မသုံးပါ သို့မဟုတ် parse အောင်မြင်ပြီးနောက်မှ ခေါ်ပါ။
- API မအောင်မြင်လျှင် valid cache data ကို မထိနှင့် မရေးပါ။
- Authentication state သည် server-authoritative ဖြစ်သည်။ Cached `/auth/me` က token valid မှုကို မသက်သေပြနိုင်ပါ။
- Logout သို့မဟုတ် account switch လျှင် private cache data ကို ဖယ်ရှားပါ။ ဤ implementation တွင် sign-in နှင့် sign-out လုပ်စဉ် cache အားလုံးကို ဖယ်သည်။
- Payment, reservation, maintenance, complaints စသည့် server-authoritative state များကို sync ပြီး server မှ ပြန်ယူပါ။ Offline တွင် write ကို replay မလုပ်ပါ။
- POST, PUT, PATCH, DELETE ကို cache system မှ မ queue ပါ။ Offline write ကို ဤ guide မှ မလုပ်ပါ။

## 6. Troubleshooting

- Stale data: TTL ကို စစ်ပြီး related mutation ပြီးလျှင် `ApiCacheStore.invalidate` သို့မဟုတ် `invalidatePrefix` ကို ခေါ်ပါ။
- Offline startup တွင် cache လွတ်: repository သည် မူလ `ApiException` ကို throw သည်။ Controller က `errorMessage` ပြသသင့်သည်။
- Serialization/type errors: `toJson()` နှင့် `fromJson()` key နှင့် nullable shape တူအောင် ပြုလုပ်ပါ။
- Migration errors: schema version စစ်ပြီး `onUpgrade` သုံးပါ။ Development အဆင့်တွင်သာ local database ဖျက်ပါ။ Production တွင်မပါ။
- Duplicate requests: controller loading flag ဖြင့် tap နှင့် startup route ကို protect ပါ (`AuthController.isSubmitting` ကဲ့သို့)။
- Offline detection: connectivity widget မလုံခြုံပါ။ Request failure နှင့် `ApiException.isRetryable` ကို မှီခိုပါ။ Wi-Fi/mobile ချိတ်ဆက်ထားသော်လည်း API reachable မဖြစ်နိုင်ပါ။
- Debug log: sensitive data မပါသော payload များအတွက်သာ `superPrint` သုံးပါ။ Token, password, ပြည့်စုံသော auth response, private resident data ကို မ log ပါ။

## 7. နောက်လာမည့် API များအတွက် Checklist

- [ ] Endpoint သည် read-only GET ဖြစ်ပြီး cache လုပ်ရန် စိတ်ချရသည်။
- [ ] Model တွင် `toJson` နှင့် `fromJson` compatible ရှိသည်။
- [ ] Endpoint, account, query input ပါသော deterministic cache key သတ်မှတ်သည်။
- [ ] TTL ရွေးသည်။
- [ ] `ApiCacheStore` inject သည်။
- [ ] API response အောင်မြင်မှသာ write သည်။
- [ ] retryable failure နှင့် fresh cache ကိုသာ fallback သည်။
- [ ] non-retryable နှင့် expired/empty cache failure ကို rethrow သည်။
- [ ] GetX controller တွင် loading, error, data, last-updated state ပြသည်။
- [ ] related mutation ပြီး cache invalidation လုပ်သည်။
- [ ] logout/account change လုပ်စဉ် cache ရှင်းသည်။
- [ ] `flutter pub get`, `flutter pub run build_runner build`, `flutter analyze`, `flutter test` ကို ပြုလုပ်သည်။
- [ ] unrelated test သို့မဟုတ် offline write queue မထည့်ပါ။
