#import "Venmo.h"
#import <VENCore/VENUserPayloadKeys.h>

@interface Venmo (Private)

@property (assign, nonatomic) BOOL internalDevelopment;

- (NSString *)baseURLPath;

- (instancetype)initWithAppId:(NSString *)appId
                       secret:(NSString *)appSecret
                         name:(NSString *)appName;

- (NSString *)URLPathWithType:(VENTransactionType)type
                       amount:(NSUInteger)amount
                         note:(NSString *)note
                    recipient:(NSString *)recipientHandle;

- (NSString *)currentDeviceIdentifier;

@end

SpecBegin(Venmo)

describe(@"startWithAppId:secret:name: and sharedInstance", ^{

    __block NSString *appId = @"foobarbaz";

    afterAll(^{
        [VENSession deleteSessionWithAppId:appId];
    });

    it(@"should create a singleton instance", ^{
        [Venmo startWithAppId:appId secret:@"bar" name:@"Foo Bar App"];
        Venmo *sharedVenmo = [Venmo sharedInstance];
        expect(sharedVenmo).toNot.beNil();

        [Venmo startWithAppId:appId secret:@"bar" name:@"Foo Bar App"];
        expect([Venmo sharedInstance]).to.equal(sharedVenmo);
    });

    it(@"should create an instance with a cached session", ^{
        NSString *accessToken = @"octocat1234foobar";
        NSString *refreshToken = @"new1234octocatplz";
        NSUInteger expiresIn = 1234;

        VENSession *session = [[VENSession alloc] init];
        NSDictionary *userDictionary = @{VENUserKeyExternalId: @"12345678"};

        VENUser *user = [[VENUser alloc] initWithDictionary:userDictionary];

        [session openWithAccessToken:accessToken refreshToken:refreshToken expiresIn:expiresIn user:user];
        expect(session.state).to.equal(VENSessionStateOpen);

        // save the session
        BOOL saved = [session saveWithAppId:appId];
        expect(saved).to.equal(YES);

        BOOL cachedSessionFound = [Venmo startWithAppId:appId secret:@"foo" name:@"my app"];
        Venmo *sharedVenmo = [Venmo sharedInstance];

        // we should get the formerly saved session
        expect(cachedSessionFound).to.equal(YES);
        expect(sharedVenmo.session.accessToken).to.equal(accessToken);
        expect(sharedVenmo.session.refreshToken).to.equal(refreshToken);
        expect(sharedVenmo.session.user).to.equal(user);
        expect(sharedVenmo.session.state).to.equal(VENSessionStateOpen);
    });

});

describe(@"requestPermissions:withCompletionHandler", ^{

    __block id mockApplication;
    __block id mockSharedApplication;
    __block id mockVenmo;
    __block NSString *appId;
    __block NSString *appSecret;
    __block NSString *appName;

    beforeAll(^{
        // Turn [UIApplication sharedApplication] into a partial mock.
        mockApplication = [OCMockObject niceMockForClass:[UIApplication class]];
        mockSharedApplication = [OCMockObject niceMockForClass:[UIApplication class]];
        [[[mockApplication stub] andReturn:mockSharedApplication] sharedApplication];

        // Create a partial mock for Venmo
        appId = @"foo";
        appSecret = @"bar";
        appName = @"AppName";
        Venmo *venmo = [[Venmo alloc] initWithAppId:appId secret:appSecret name:appName];
        mockVenmo = [OCMockObject partialMockForObject:venmo];
    });

    afterAll(^{
        [mockApplication stopMocking];
        [mockSharedApplication stopMocking];
        [mockVenmo stopMocking];
        [VENSession deleteSessionWithAppId:appId];
    });

    afterEach(^{
        [mockVenmo stopMocking];
    });

    it(@"should use venmo:// if venmoAppInstalled is true", ^{
        [[[mockVenmo stub] andReturnValue:OCMOCK_VALUE(YES)] venmoAppInstalled];
        [[mockSharedApplication expect] openURL:[OCMArg checkWithBlock:^BOOL(NSURL *url) {
            expect([url scheme]).to.equal(@"venmo");
            return YES;
        }]];
        [mockVenmo requestPermissions:@[] withCompletionHandler:^(BOOL success, NSError *error) {
        }];
    });

    it(@"should use baseURLPath if venmoAppInstalled is false", ^{
        [[[mockVenmo stub] andReturnValue:OCMOCK_VALUE(NO)] venmoAppInstalled];
        [[[mockVenmo stub] andReturn:@"foobaseurl"] baseURLPath];
        [[mockSharedApplication expect] openURL:[OCMArg checkWithBlock:^BOOL(NSURL *url) {
            expect([url absoluteString]).to.contain(@"foobaseurl");
            return YES;
        }]];
        [mockVenmo requestPermissions:@[] withCompletionHandler:^(BOOL success, NSError *error) {
        }];
    });

});


describe(@"logout", ^{

    __block NSString *appId;

    it(@"should close the current session and delete the cached session", ^{
        NSString *accessToken = @"octocat1234foobar";
        NSString *refreshToken = @"new1234octocatplz";
        appId = @"12345678";
        NSUInteger expiresIn = 1234;

        id mockVENSession = [OCMockObject niceMockForClass:[VENSession class]];
        [[mockVENSession expect] deleteSessionWithAppId:OCMOCK_ANY];

        VENSession *session = [[VENSession alloc] init];
        VENUser *user = [[VENUser alloc] init];
        [session openWithAccessToken:accessToken refreshToken:refreshToken expiresIn:expiresIn user:user];

        // save the session
        BOOL saved = [session saveWithAppId:appId];
        expect(saved).to.equal(YES);

        [Venmo startWithAppId:appId secret:@"bar" name:@"Foo Bar App"];
        Venmo *venmo = [Venmo sharedInstance];
        expect(venmo.session.state).to.equal(VENSessionStateOpen);
        [venmo logout];

        expect(venmo.session.state).to.equal(VENSessionStateClosed);
        expect(venmo.session.accessToken).to.beNil();
        expect(venmo.session.refreshToken).to.beNil();
        expect(venmo.session.refreshToken).to.beNil();
        expect(venmo.session.user).to.beNil();

        [mockVENSession verify];
    });

});

#pragma mark - Internal methods

describe(@"initWithAppId:secret:name:", ^{

    __block Venmo *venmo;

    beforeEach(^{
        venmo = [[Venmo alloc] initWithAppId:@"foo" secret:@"bar" name:@"Foo Bar App"];
    });

    it(@"should have an internal development flag", ^{
        expect(venmo.internalDevelopment).to.beFalsy();
        venmo.internalDevelopment = YES;
        expect(venmo.internalDevelopment).to.beTruthy();
    });

    it(@"should correctly set the app id, secret, and name", ^{
        expect(venmo.appId).to.equal(@"foo");
        expect(venmo.appSecret).to.equal(@"bar");
        expect(venmo.appName).to.equal(@"Foo Bar App");
    });

    it(@"should correctly set the current session to a closed session", ^{
        expect(venmo.session.state).to.equal(VENSessionStateClosed);
    });
});

describe(@"baseURLPath", ^{

    __block Venmo *venmo;

    beforeEach(^{
        venmo = [[Venmo alloc] initWithAppId:@"foo" secret:@"bar" name:@"Foo Bar App"];
    });

    it(@"should return correct base URL path based on internal development flag.", ^{
        expect([venmo baseURLPath]).to.equal(@"http://api.venmo.com/v1/");
        venmo.internalDevelopment = YES;
        expect([venmo baseURLPath]).to.equal(@"http://api.dev.venmo.com/v1/");
    });
});

describe(@"URLPathWithType:amount:note:recipient:", ^{

    __block Venmo *venmo;
    __block id mockVenmo;
    __block NSString *appId;
    __block NSString *appSecret;
    __block NSString *appName;

    beforeEach(^{
        appId = @"foo";
        appSecret = @"bar";
        appName = @"AppName";

        venmo = [[Venmo alloc] initWithAppId:appId secret:appSecret name:appName];
        mockVenmo = [OCMockObject partialMockForObject:venmo];
        [[[mockVenmo stub] andReturn:@"deviceId"] currentDeviceIdentifier];
    });

    it(@"should return the correct path for a charge", ^{
        NSString *path = [mockVenmo URLPathWithType:VENTransactionTypePay amount:100 note:@"test" recipient:@"cookie"];
        expect([path rangeOfString:@"client=ios"].location).toNot.equal(NSNotFound);
        expect([path rangeOfString:@"app_name=AppName"].location).toNot.equal(NSNotFound);
        expect([path rangeOfString:@"device_id=deviceId"].location).toNot.equal(NSNotFound);
        expect([path rangeOfString:@"amount=1.00"].location).toNot.equal(NSNotFound);
        expect([path rangeOfString:@"txn=pay"].location).toNot.equal(NSNotFound);
        expect([path rangeOfString:@"recipients=cookie"].location).toNot.equal(NSNotFound);
        expect([path rangeOfString:@"note=test"].location).toNot.equal(NSNotFound);
        NSString *versionString = [NSString stringWithFormat:@"app_version=%@", VEN_CURRENT_SDK_VERSION];
        expect([path rangeOfString:versionString].location).toNot.equal(NSNotFound);
    });

    it(@"should return the correct path for a payment", ^{
        NSString *path = [mockVenmo URLPathWithType:VENTransactionTypeCharge amount:9999 note:@"testnote" recipient:@"cookie@venmo.com"];
        expect([path rangeOfString:@"txn=charge"].location).toNot.equal(NSNotFound);
    });
    
});

SpecEnd