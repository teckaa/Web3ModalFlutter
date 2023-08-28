// ignore_for_file: depend_on_referenced_packages

import 'package:event/event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:walletconnect_modal_flutter/services/explorer/explorer_service_singleton.dart';
import 'package:walletconnect_modal_flutter/services/utils/url/url_utils_singleton.dart';
import 'package:web3modal_flutter/services/blockchain_api_service/blockchain_api_utils_singleton.dart';
import 'package:web3modal_flutter/services/blockchain_api_service/blockchain_identity.dart';
import 'package:web3modal_flutter/services/network_service.dart/network_service_singleton.dart';
import 'package:web3modal_flutter/services/storage_service/storage_service_singleton.dart';
import 'package:web3modal_flutter/utils/eth_util.dart';
import 'package:web3modal_flutter/web3modal_flutter.dart';

import '../mock_classes.mocks.dart';
import '../test_data.dart';

void main() {
  group('WalletConnectModalService', () {
    late W3MService service;
    late MockWeb3App web3App;
    late MockSessions sessions;
    late MockExplorerService es;
    late Core core;
    late MockRelayClient mockRelayClient;
    late MockNetworkService mockNetworkService;
    late MockStorageService mockStorageService;
    late MockBlockchainApiUtils mockBlockchainApiUtils;
    late MockEVMService mockEVMService;
    late MockUrlUtils mockUrlUtils;

    late Event<SessionDelete> onSessionDelete = Event<SessionDelete>();

    setUp(() async {
      // Web3App Mocking
      web3App = MockWeb3App();
      when(web3App.init()).thenAnswer((_) async {});
      core = Core(projectId: 'projectId');
      mockRelayClient = MockRelayClient();
      when(mockRelayClient.onRelayClientError).thenReturn(Event<ErrorEvent>());
      when(mockRelayClient.onRelayClientConnect).thenReturn(Event<EventArgs>());
      core.relayClient = mockRelayClient;
      when(web3App.core).thenReturn(
        core,
      );
      when(web3App.metadata).thenReturn(
        metadata,
      );
      when(web3App.onSessionDelete).thenReturn(
        onSessionDelete,
      );
      when(web3App.onSessionConnect).thenReturn(
        Event<SessionConnect>(),
      );
      when(web3App.onSessionUpdate).thenReturn(
        Event<SessionUpdate>(),
      );
      when(web3App.onSessionEvent).thenReturn(
        Event<SessionEvent>(),
      );
      when(
        web3App.request(
          topic: anyNamed('topic'),
          chainId: anyNamed('chainId'),
          request: anyNamed('request'),
        ),
      ).thenAnswer((_) => Future.value(true));
      sessions = MockSessions();
      when(web3App.sessions).thenReturn(
        sessions,
      );
      when(sessions.getAll()).thenReturn(
        [],
      );

      service = W3MService(
        web3App: web3App,
      );

      // Service mocking
      mockNetworkService = MockNetworkService();
      mockStorageService = MockStorageService();
      mockBlockchainApiUtils = MockBlockchainApiUtils();
      es = MockExplorerService();
      mockEVMService = MockEVMService();
      mockUrlUtils = MockUrlUtils();
      networkService.instance = mockNetworkService;
      storageService.instance = mockStorageService;
      explorerService.instance = es;
      blockchainApiUtils.instance = mockBlockchainApiUtils;
      urlUtils.instance = mockUrlUtils;

      // Change all chain presets to use our mock EVMService
      for (var entry in ChainData.chainPresets.entries) {
        ChainData.chainPresets[entry.key] = entry.value.copyWith(
          ledgerService: mockEVMService,
        );
      }

      when(es.init()).thenAnswer((_) async {});
      // await WalletConnectModalServices.explorer.init();
      when(mockStorageService.getString(W3MService.selectedChainId))
          .thenReturn('1');
      when(mockStorageService.setString(W3MService.selectedChainId, any))
          .thenAnswer((_) => Future.value(true));
      when(
        es.getAssetImageUrl(
          imageId: anyNamed('imageId'),
        ),
      ).thenReturn('abc');
      when(es.getRedirect(name: anyNamed("name"))).thenReturn(null);
      when(mockEVMService.getBalance(any, any)).thenAnswer(
        (_) => Future.value(1.0),
      );
      when(mockBlockchainApiUtils.getIdentity(any, any)).thenAnswer(
        (realInvocation) => Future.value(
          const BlockchainIdentity(
            avatar: null,
            name: null,
          ),
        ),
      );
      when(mockUrlUtils.launchUrl(any)).thenAnswer(
        (realInvocation) => Future.value(true),
      );
      // when(
      //   mockUrlUtils.launchRedirect(
      //     nativeUri: anyNamed("nativeUri"),
      //     universalUri: anyNamed('universalUri'),
      //   ),
      // ).thenAnswer(
      //   (_) async {},
      // );
    });

    group('Constructor', () {
      test('initializes blockchainApiUtils with projectId', () {
        W3MService(
          projectId: 'projectId',
          metadata: metadata,
        );

        expect(blockchainApiUtils.instance!.projectId, 'projectId');
      });
    });

    group('init', () {
      test(
          'should call init on services, set optional namespaces, then skip init again',
          () async {
        when(es.init()).thenAnswer((_) async {});

        int counter = 0;
        f() {
          counter++;
        }

        service.addListener(f);

        await service.init();

        verify(mockNetworkService.init()).called(1);
        verify(mockStorageService.init()).called(1);

        expect(service.isInitialized, isTrue);
        final List<String> chainIds = [];
        for (final String id in ChainData.chainPresets.keys) {
          chainIds.add('eip155:$id');
        }
        final Map<String, RequiredNamespace> optionalNamespaces = {
          'eip155': RequiredNamespace(
            methods: EthUtil.ethMethods,
            chains: chainIds,
            events: EthUtil.ethEvents,
          ),
        };
        expect(
          service.optionalNamespaces,
          optionalNamespaces,
        );
        expect(counter, 2);

        await service.init();

        verifyNever(mockNetworkService.init());
        verifyNever(mockStorageService.init());

        expect(service.isInitialized, isTrue);
        expect(counter, 2);

        service.removeListener(f);
      });

      test(
          'should setSelectedChain if sessions is not empty and we have a stored selectedChainId',
          () async {
        when(sessions.getAll()).thenReturn(
          [testSession],
        );

        int counter = 0;
        f() {
          counter++;
        }

        service.addListener(f);

        await service.init();

        verify(
          mockStorageService.getString(W3MService.selectedChainId),
        ).called(1);
        verify(
          mockStorageService.setString(W3MService.selectedChainId, '1'),
        ).called(1);
        verify(es.getAssetImageUrl(imageId: anyNamed('imageId'))).called(1);
        verify(mockEVMService.getBalance(any, any)).called(1);
        verify(mockBlockchainApiUtils.getIdentity(any, any)).called(1);
        expect(service.selectedChain, ChainData.chainPresets['1']);
        expect(counter, 4);

        service.removeListener(f);
      });
    });

    group('setSelectedChain', () {
      test('throws if _checkInitialized fails', () async {
        expect(
          () => service.setSelectedChain(ChainData.chainPresets['1']!),
          throwsA(isA<StateError>()),
        );
      });

      test('happy path + null chain', () async {
        when(sessions.getAll()).thenReturn(
          [testSession],
        );

        int counter = 0;
        f() {
          counter++;
        }

        service.addListener(f);

        // Init the service will use the test session properly
        await service.init();
        // WalletConnectModal, setOptionalNamespaces, setSelectedChain (calls it twice)
        expect(counter, 4);
        verify(
          mockStorageService.setString(W3MService.selectedChainId, '1'),
        ).called(1);
        verify(es.getAssetImageUrl(imageId: anyNamed('imageId'))).called(1);
        verify(mockEVMService.getBalance(any, any)).called(1);
        verify(mockBlockchainApiUtils.getIdentity(any, any)).called(1);
        expect(service.selectedChain, ChainData.chainPresets['1']);
        expect(
          service.requiredNamespaces,
          ChainData.chainPresets['1']!.requiredNamespaces,
        );

        // Chain swap to polygon
        await service.setSelectedChain(ChainData.chainPresets['137']!);

        //
        expect(counter, 6);
        verify(
          mockStorageService.setString(W3MService.selectedChainId, '137'),
        ).called(1);
        verify(es.getAssetImageUrl(imageId: anyNamed('imageId'))).called(1);
        verify(mockEVMService.getBalance(any, any)).called(1);
        verify(mockBlockchainApiUtils.getIdentity(any, any)).called(1);
        expect(service.selectedChain, ChainData.chainPresets['137']);
        expect(
          service.requiredNamespaces,
          ChainData.chainPresets['137']!.requiredNamespaces,
        );

        // Setting selected chain to null will disconnect
        await service.setSelectedChain(null);
        onSessionDelete.broadcast(SessionDelete(
          'topic',
        ));

        verify(mockStorageService.setString(
          W3MService.selectedChainId,
          '',
        ));
        verify(
          web3App.disconnectSession(
            topic: anyNamed('topic'),
            reason: anyNamed('reason'),
          ),
        ).called(2);
        expect(service.session == null, true);
        expect(service.selectedChain, null);
        expect(service.chainBalance, null);
        expect(service.tokenImageUrl, null);
        expect(
          service.requiredNamespaces,
          {},
        );

        expect(counter, 8); // setRequiredNamespaces, disconnect
      });

      test('switch wallet if all conditions are met', () async {
        when(sessions.getAll()).thenReturn(
          [testSessionWalletSwap],
        );

        await service.init();

        await service.setSelectedChain(ChainData.chainPresets['1']!);
        await service.setSelectedChain(ChainData.chainPresets['137']!);

        // Check that we switched wallets
        verify(
          web3App.request(
            topic: anyNamed('topic'),
            chainId: anyNamed('chainId'),
            request: anyNamed('request'),
          ),
        ).called(1);
        verify(es.getRedirect(name: anyNamed('name'))).called(1);
        verify(
          mockUrlUtils.launchUrl(any),
        ).called(1);
      });
    });
  });
}