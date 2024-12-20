import bison/bson
import mug

pub type Error {
  StructureError
  AuthenticationError
  ActorError
  TCPError(mug.Error)
  ConnectionStringError
  WriteErrors(List(WriteError))
  ServerError(MongoServerError)
}

pub type WriteError {
  WriteError(Int, String, bson.Value)
}

pub fn is_retriable_error(error: MongoServerError) -> Bool {
  case error {
    HostUnreachable(_)
    | HostNotFound(_)
    | NetworkTimeout(_)
    | ShutdownInProgress(_)
    | PrimarySteppedDown(_)
    | ExceededTimeLimit(_)
    | ConnectionPoolExpired(_)
    | SocketException(_)
    | NotWritablePrimary(_)
    | InterruptedAtShutdown(_)
    | InterruptedDueToReplStateChange(_)
    | NotPrimaryNoSecondaryOk(_)
    | NotPrimaryOrSecondary(_) -> True
    _ -> False
  }
}

pub fn is_not_primary_error(error: MongoServerError) -> Bool {
  case error {
    PrimarySteppedDown(_)
    | NotWritablePrimary(_)
    | InterruptedDueToReplStateChange(_)
    | NotPrimaryNoSecondaryOk(_)
    | NotPrimaryOrSecondary(_) -> True
    _ -> False
  }
}

/// https://github.com/mongodb/mongo/blob/master/src/mongo/base/error_codes.yml
pub type MongoServerError {
  OK(String)
  InternalError(String)
  BadValue(String)
  NoSuchKey(String)
  GraphContainsCycle(String)
  HostUnreachable(String)
  HostNotFound(String)
  UnknownError(String)
  FailedToParse(String)
  CannotMutateObject(String)
  UserNotFound(String)
  UnsupportedFormat(String)
  Unauthorized(String)
  TypeMismatch(String)
  Overflow(String)
  InvalidLength(String)
  ProtocolError(String)
  AuthenticationFailed(String)
  CannotReuseObject(String)
  IllegalOperation(String)
  EmptyArrayOperation(String)
  InvalidBSON(String)
  AlreadyInitialized(String)
  LockTimeout(String)
  RemoteValidationError(String)
  NamespaceNotFound(String)
  IndexNotFound(String)
  PathNotViable(String)
  NonExistentPath(String)
  InvalidPath(String)
  RoleNotFound(String)
  RolesNotRelated(String)
  PrivilegeNotFound(String)
  CannotBackfillArray(String)
  UserModificationFailed(String)
  RemoteChangeDetected(String)
  FileRenameFailed(String)
  FileNotOpen(String)
  FileStreamFailed(String)
  ConflictingUpdateOperators(String)
  FileAlreadyOpen(String)
  LogWriteFailed(String)
  CursorNotFound(String)
  UserDataInconsistent(String)
  LockBusy(String)
  NoMatchingDocument(String)
  NamespaceExists(String)
  InvalidRoleModification(String)
  MaxTimeMSExpired(String)
  ManualInterventionRequired(String)
  DollarPrefixedFieldName(String)
  InvalidIdField(String)
  NotSingleValueField(String)
  InvalidDBRef(String)
  EmptyFieldName(String)
  DottedFieldName(String)
  RoleModificationFailed(String)
  CommandNotFound(String)
  ShardKeyNotFound(String)
  OplogOperationUnsupported(String)
  StaleShardVersion(String)
  WriteConcernFailed(String)
  MultipleErrorsOccurred(String)
  ImmutableField(String)
  CannotCreateIndex(String)
  IndexAlreadyExists(String)
  AuthSchemaIncompatible(String)
  ShardNotFound(String)
  ReplicaSetNotFound(String)
  InvalidOptions(String)
  InvalidNamespace(String)
  NodeNotFound(String)
  WriteConcernLegacyOK(String)
  NoReplicationEnabled(String)
  OperationIncomplete(String)
  CommandResultSchemaViolation(String)
  UnknownReplWriteConcern(String)
  RoleDataInconsistent(String)
  NoMatchParseContext(String)
  NoProgressMade(String)
  RemoteResultsUnavailable(String)
  IndexOptionsConflict(String)
  IndexKeySpecsConflict(String)
  CannotSplit(String)
  NetworkTimeout(String)
  CallbackCanceled(String)
  ShutdownInProgress(String)
  SecondaryAheadOfPrimary(String)
  InvalidReplicaSetConfig(String)
  NotYetInitialized(String)
  NotSecondary(String)
  OperationFailed(String)
  NoProjectionFound(String)
  DBPathInUse(String)
  UnsatisfiableWriteConcern(String)
  OutdatedClient(String)
  IncompatibleAuditMetadata(String)
  NewReplicaSetConfigurationIncompatible(String)
  NodeNotElectable(String)
  IncompatibleShardingMetadata(String)
  DistributedClockSkewed(String)
  LockFailed(String)
  InconsistentReplicaSetNames(String)
  ConfigurationInProgress(String)
  CannotInitializeNodeWithData(String)
  NotExactValueField(String)
  WriteConflict(String)
  InitialSyncFailure(String)
  InitialSyncOplogSourceMissing(String)
  CommandNotSupported(String)
  DocTooLargeForCapped(String)
  ConflictingOperationInProgress(String)
  NamespaceNotSharded(String)
  InvalidSyncSource(String)
  OplogStartMissing(String)
  DocumentValidationFailure(String)
  NotAReplicaSet(String)
  IncompatibleElectionProtocol(String)
  CommandFailed(String)
  RPCProtocolNegotiationFailed(String)
  UnrecoverableRollbackError(String)
  LockNotFound(String)
  LockStateChangeFailed(String)
  SymbolNotFound(String)
  FailedToSatisfyReadPreference(String)
  ReadConcernMajorityNotAvailableYet(String)
  StaleTerm(String)
  CappedPositionLost(String)
  IncompatibleShardingConfigVersion(String)
  RemoteOplogStale(String)
  JSInterpreterFailure(String)
  InvalidSSLConfiguration(String)
  SSLHandshakeFailed(String)
  JSUncatchableError(String)
  CursorInUse(String)
  IncompatibleCatalogManager(String)
  PooledConnectionsDropped(String)
  ExceededMemoryLimit(String)
  ZLibError(String)
  ReadConcernMajorityNotEnabled(String)
  NoConfigPrimary(String)
  StaleEpoch(String)
  OperationCannotBeBatched(String)
  OplogOutOfOrder(String)
  ChunkTooBig(String)
  InconsistentShardIdentity(String)
  CannotApplyOplogWhilePrimary(String)
  CanRepairToDowngrade(String)
  MustUpgrade(String)
  DurationOverflow(String)
  MaxStalenessOutOfRange(String)
  IncompatibleCollationVersion(String)
  CollectionIsEmpty(String)
  ZoneStillInUse(String)
  InitialSyncActive(String)
  ViewDepthLimitExceeded(String)
  CommandNotSupportedOnView(String)
  OptionNotSupportedOnView(String)
  InvalidPipelineOperator(String)
  CommandOnShardedViewNotSupportedOnMongod(String)
  TooManyMatchingDocuments(String)
  CannotIndexParallelArrays(String)
  TransportSessionClosed(String)
  TransportSessionNotFound(String)
  TransportSessionUnknown(String)
  QueryPlanKilled(String)
  FileOpenFailed(String)
  ZoneNotFound(String)
  RangeOverlapConflict(String)
  WindowsPdhError(String)
  BadPerfCounterPath(String)
  AmbiguousIndexKeyPattern(String)
  InvalidViewDefinition(String)
  ClientMetadataMissingField(String)
  ClientMetadataAppNameTooLarge(String)
  ClientMetadataDocumentTooLarge(String)
  ClientMetadataCannotBeMutated(String)
  LinearizableReadConcernError(String)
  IncompatibleServerVersion(String)
  PrimarySteppedDown(String)
  MasterSlaveConnectionFailure(String)
  FailPointEnabled(String)
  NoShardingEnabled(String)
  BalancerInterrupted(String)
  ViewPipelineMaxSizeExceeded(String)
  InvalidIndexSpecificationOption(String)
  ReplicaSetMonitorRemoved(String)
  ChunkRangeCleanupPending(String)
  CannotBuildIndexKeys(String)
  NetworkInterfaceExceededTimeLimit(String)
  ShardingStateNotInitialized(String)
  TimeProofMismatch(String)
  ClusterTimeFailsRateLimiter(String)
  NoSuchSession(String)
  InvalidUUID(String)
  TooManyLocks(String)
  StaleClusterTime(String)
  CannotVerifyAndSignLogicalTime(String)
  KeyNotFound(String)
  IncompatibleRollbackAlgorithm(String)
  DuplicateSession(String)
  AuthenticationRestrictionUnmet(String)
  DatabaseDropPending(String)
  ElectionInProgress(String)
  IncompleteTransactionHistory(String)
  UpdateOperationFailed(String)
  FTDCPathNotSet(String)
  FTDCPathAlreadySet(String)
  IndexModified(String)
  CloseChangeStream(String)
  IllegalOpMsgFlag(String)
  QueryFeatureNotAllowed(String)
  TransactionTooOld(String)
  AtomicityFailure(String)
  CannotImplicitlyCreateCollection(String)
  SessionTransferIncomplete(String)
  MustDowngrade(String)
  DNSHostNotFound(String)
  DNSProtocolError(String)
  MaxSubPipelineDepthExceeded(String)
  TooManyDocumentSequences(String)
  RetryChangeStream(String)
  InternalErrorNotSupported(String)
  ForTestingErrorExtraInfo(String)
  CursorKilled(String)
  NotImplemented(String)
  SnapshotTooOld(String)
  DNSRecordTypeMismatch(String)
  ConversionFailure(String)
  CannotCreateCollection(String)
  IncompatibleWithUpgradedServer(String)
  BrokenPromise(String)
  SnapshotUnavailable(String)
  ProducerConsumerQueueBatchTooLarge(String)
  ProducerConsumerQueueEndClosed(String)
  StaleDbVersion(String)
  StaleChunkHistory(String)
  NoSuchTransaction(String)
  ReentrancyNotAllowed(String)
  FreeMonHttpInFlight(String)
  FreeMonHttpTemporaryFailure(String)
  FreeMonHttpPermanentFailure(String)
  TransactionCommitted(String)
  TransactionTooLarge(String)
  UnknownFeatureCompatibilityVersion(String)
  KeyedExecutorRetry(String)
  InvalidResumeToken(String)
  TooManyLogicalSessions(String)
  ExceededTimeLimit(String)
  OperationNotSupportedInTransaction(String)
  TooManyFilesOpen(String)
  OrphanedRangeCleanUpFailed(String)
  FailPointSetFailed(String)
  PreparedTransactionInProgress(String)
  CannotBackup(String)
  DataModifiedByRepair(String)
  RepairedReplicaSetNode(String)
  JSInterpreterFailureWithStack(String)
  MigrationConflict(String)
  ProducerConsumerQueueProducerQueueDepthExceeded(String)
  ProducerConsumerQueueConsumed(String)
  ExchangePassthrough(String)
  IndexBuildAborted(String)
  AlarmAlreadyFulfilled(String)
  UnsatisfiableCommitQuorum(String)
  ClientDisconnect(String)
  ChangeStreamFatalError(String)
  TransactionCoordinatorSteppingDown(String)
  TransactionCoordinatorReachedAbortDecision(String)
  WouldChangeOwningShard(String)
  ForTestingErrorExtraInfoWithExtraInfoInNamespace(String)
  IndexBuildAlreadyInProgress(String)
  ChangeStreamHistoryLost(String)
  TransactionCoordinatorDeadlineTaskCanceled(String)
  ChecksumMismatch(String)
  WaitForMajorityServiceEarlierOpTimeAvailable(String)
  TransactionExceededLifetimeLimitSeconds(String)
  NoQueryExecutionPlans(String)
  QueryExceededMemoryLimitNoDiskUseAllowed(String)
  InvalidSeedList(String)
  InvalidTopologyType(String)
  InvalidHeartBeatFrequency(String)
  TopologySetNameRequired(String)
  HierarchicalAcquisitionLevelViolation(String)
  InvalidServerType(String)
  OCSPCertificateStatusRevoked(String)
  RangeDeletionAbandonedBecauseCollectionWithUUIDDoesNotExist(String)
  DataCorruptionDetected(String)
  OCSPCertificateStatusUnknown(String)
  SplitHorizonChange(String)
  ShardInvalidatedForTargeting(String)
  ReadThroughCacheLookupCanceled(String)
  RangeDeletionAbandonedBecauseTaskDocumentDoesNotExist(String)
  CurrentConfigNotCommittedYet(String)
  ExhaustCommandFinished(String)
  PeriodicJobIsStopped(String)
  TransactionCoordinatorCanceled(String)
  OperationIsKilledAndDelisted(String)
  ResumableRangeDeleterDisabled(String)
  ObjectIsBusy(String)
  TooStaleToSyncFromSource(String)
  QueryTrialRunCompleted(String)
  ConnectionPoolExpired(String)
  ForTestingOptionalErrorExtraInfo(String)
  MovePrimaryInProgress(String)
  TenantMigrationConflict(String)
  TenantMigrationCommitted(String)
  APIVersionError(String)
  APIStrictError(String)
  APIDeprecationError(String)
  TenantMigrationAborted(String)
  OplogQueryMinTsMissing(String)
  NoSuchTenantMigration(String)
  TenantMigrationAccessBlockerShuttingDown(String)
  TenantMigrationInProgress(String)
  SkipCommandExecution(String)
  FailedToRunWithReplyBuilder(String)
  CannotDowngrade(String)
  ServiceExecutorInShutdown(String)
  MechanismUnavailable(String)
  TenantMigrationForgotten(String)
  SocketException(String)
  CannotGrowDocumentInCappedNamespace(String)
  NotWritablePrimary(String)
  BSONObjectTooLarge(String)
  DuplicateKey(String)
  InterruptedAtShutdown(String)
  Interrupted(String)
  InterruptedDueToReplStateChange(String)
  BackgroundOperationInProgressForDatabase(String)
  BackgroundOperationInProgressForNamespace(String)
  MergeStageNoMatchingDocument(String)
  DatabaseDifferCase(String)
  StaleConfig(String)
  NotPrimaryNoSecondaryOk(String)
  NotPrimaryOrSecondary(String)
  OutOfDiskSpace(String)
  ClientMarkedKilled(String)
}

pub const code_to_server_error = [
  #(0, OK), #(1, InternalError), #(2, BadValue), #(4, NoSuchKey),
  #(5, GraphContainsCycle), #(6, HostUnreachable), #(7, HostNotFound),
  #(8, UnknownError), #(9, FailedToParse), #(10, CannotMutateObject),
  #(11, UserNotFound), #(12, UnsupportedFormat), #(13, Unauthorized),
  #(14, TypeMismatch), #(15, Overflow), #(16, InvalidLength),
  #(17, ProtocolError), #(18, AuthenticationFailed), #(19, CannotReuseObject),
  #(20, IllegalOperation), #(21, EmptyArrayOperation), #(22, InvalidBSON),
  #(23, AlreadyInitialized), #(24, LockTimeout), #(25, RemoteValidationError),
  #(26, NamespaceNotFound), #(27, IndexNotFound), #(28, PathNotViable),
  #(29, NonExistentPath), #(30, InvalidPath), #(31, RoleNotFound),
  #(32, RolesNotRelated), #(33, PrivilegeNotFound), #(34, CannotBackfillArray),
  #(35, UserModificationFailed), #(36, RemoteChangeDetected),
  #(37, FileRenameFailed), #(38, FileNotOpen), #(39, FileStreamFailed),
  #(40, ConflictingUpdateOperators), #(41, FileAlreadyOpen),
  #(42, LogWriteFailed), #(43, CursorNotFound), #(45, UserDataInconsistent),
  #(46, LockBusy), #(47, NoMatchingDocument), #(48, NamespaceExists),
  #(49, InvalidRoleModification), #(50, MaxTimeMSExpired),
  #(51, ManualInterventionRequired), #(52, DollarPrefixedFieldName),
  #(53, InvalidIdField), #(54, NotSingleValueField), #(55, InvalidDBRef),
  #(56, EmptyFieldName), #(57, DottedFieldName), #(58, RoleModificationFailed),
  #(59, CommandNotFound), #(61, ShardKeyNotFound),
  #(62, OplogOperationUnsupported), #(63, StaleShardVersion),
  #(64, WriteConcernFailed), #(65, MultipleErrorsOccurred),
  #(66, ImmutableField), #(67, CannotCreateIndex), #(68, IndexAlreadyExists),
  #(69, AuthSchemaIncompatible), #(70, ShardNotFound), #(71, ReplicaSetNotFound),
  #(72, InvalidOptions), #(73, InvalidNamespace), #(74, NodeNotFound),
  #(75, WriteConcernLegacyOK), #(76, NoReplicationEnabled),
  #(77, OperationIncomplete), #(78, CommandResultSchemaViolation),
  #(79, UnknownReplWriteConcern), #(80, RoleDataInconsistent),
  #(81, NoMatchParseContext), #(82, NoProgressMade),
  #(83, RemoteResultsUnavailable), #(85, IndexOptionsConflict),
  #(86, IndexKeySpecsConflict), #(87, CannotSplit), #(89, NetworkTimeout),
  #(90, CallbackCanceled), #(91, ShutdownInProgress),
  #(92, SecondaryAheadOfPrimary), #(93, InvalidReplicaSetConfig),
  #(94, NotYetInitialized), #(95, NotSecondary), #(96, OperationFailed),
  #(97, NoProjectionFound), #(98, DBPathInUse),
  #(100, UnsatisfiableWriteConcern), #(101, OutdatedClient),
  #(102, IncompatibleAuditMetadata),
  #(103, NewReplicaSetConfigurationIncompatible), #(104, NodeNotElectable),
  #(105, IncompatibleShardingMetadata), #(106, DistributedClockSkewed),
  #(107, LockFailed), #(108, InconsistentReplicaSetNames),
  #(109, ConfigurationInProgress), #(110, CannotInitializeNodeWithData),
  #(111, NotExactValueField), #(112, WriteConflict), #(113, InitialSyncFailure),
  #(114, InitialSyncOplogSourceMissing), #(115, CommandNotSupported),
  #(116, DocTooLargeForCapped), #(117, ConflictingOperationInProgress),
  #(118, NamespaceNotSharded), #(119, InvalidSyncSource),
  #(120, OplogStartMissing), #(121, DocumentValidationFailure),
  #(123, NotAReplicaSet), #(124, IncompatibleElectionProtocol),
  #(125, CommandFailed), #(126, RPCProtocolNegotiationFailed),
  #(127, UnrecoverableRollbackError), #(128, LockNotFound),
  #(129, LockStateChangeFailed), #(130, SymbolNotFound),
  #(133, FailedToSatisfyReadPreference),
  #(134, ReadConcernMajorityNotAvailableYet), #(135, StaleTerm),
  #(136, CappedPositionLost), #(137, IncompatibleShardingConfigVersion),
  #(138, RemoteOplogStale), #(139, JSInterpreterFailure),
  #(140, InvalidSSLConfiguration), #(141, SSLHandshakeFailed),
  #(142, JSUncatchableError), #(143, CursorInUse),
  #(144, IncompatibleCatalogManager), #(145, PooledConnectionsDropped),
  #(146, ExceededMemoryLimit), #(147, ZLibError),
  #(148, ReadConcernMajorityNotEnabled), #(149, NoConfigPrimary),
  #(150, StaleEpoch), #(151, OperationCannotBeBatched), #(152, OplogOutOfOrder),
  #(153, ChunkTooBig), #(154, InconsistentShardIdentity),
  #(155, CannotApplyOplogWhilePrimary), #(157, CanRepairToDowngrade),
  #(158, MustUpgrade), #(159, DurationOverflow), #(160, MaxStalenessOutOfRange),
  #(161, IncompatibleCollationVersion), #(162, CollectionIsEmpty),
  #(163, ZoneStillInUse), #(164, InitialSyncActive),
  #(165, ViewDepthLimitExceeded), #(166, CommandNotSupportedOnView),
  #(167, OptionNotSupportedOnView), #(168, InvalidPipelineOperator),
  #(169, CommandOnShardedViewNotSupportedOnMongod),
  #(170, TooManyMatchingDocuments), #(171, CannotIndexParallelArrays),
  #(172, TransportSessionClosed), #(173, TransportSessionNotFound),
  #(174, TransportSessionUnknown), #(175, QueryPlanKilled),
  #(176, FileOpenFailed), #(177, ZoneNotFound), #(178, RangeOverlapConflict),
  #(179, WindowsPdhError), #(180, BadPerfCounterPath),
  #(181, AmbiguousIndexKeyPattern), #(182, InvalidViewDefinition),
  #(183, ClientMetadataMissingField), #(184, ClientMetadataAppNameTooLarge),
  #(185, ClientMetadataDocumentTooLarge), #(186, ClientMetadataCannotBeMutated),
  #(187, LinearizableReadConcernError), #(188, IncompatibleServerVersion),
  #(189, PrimarySteppedDown), #(190, MasterSlaveConnectionFailure),
  #(192, FailPointEnabled), #(193, NoShardingEnabled),
  #(194, BalancerInterrupted), #(195, ViewPipelineMaxSizeExceeded),
  #(197, InvalidIndexSpecificationOption), #(199, ReplicaSetMonitorRemoved),
  #(200, ChunkRangeCleanupPending), #(201, CannotBuildIndexKeys),
  #(202, NetworkInterfaceExceededTimeLimit), #(203, ShardingStateNotInitialized),
  #(204, TimeProofMismatch), #(205, ClusterTimeFailsRateLimiter),
  #(206, NoSuchSession), #(207, InvalidUUID), #(208, TooManyLocks),
  #(209, StaleClusterTime), #(210, CannotVerifyAndSignLogicalTime),
  #(211, KeyNotFound), #(212, IncompatibleRollbackAlgorithm),
  #(213, DuplicateSession), #(214, AuthenticationRestrictionUnmet),
  #(215, DatabaseDropPending), #(216, ElectionInProgress),
  #(217, IncompleteTransactionHistory), #(218, UpdateOperationFailed),
  #(219, FTDCPathNotSet), #(220, FTDCPathAlreadySet), #(221, IndexModified),
  #(222, CloseChangeStream), #(223, IllegalOpMsgFlag),
  #(224, QueryFeatureNotAllowed), #(225, TransactionTooOld),
  #(226, AtomicityFailure), #(227, CannotImplicitlyCreateCollection),
  #(228, SessionTransferIncomplete), #(229, MustDowngrade),
  #(230, DNSHostNotFound), #(231, DNSProtocolError),
  #(232, MaxSubPipelineDepthExceeded), #(233, TooManyDocumentSequences),
  #(234, RetryChangeStream), #(235, InternalErrorNotSupported),
  #(236, ForTestingErrorExtraInfo), #(237, CursorKilled), #(238, NotImplemented),
  #(239, SnapshotTooOld), #(240, DNSRecordTypeMismatch),
  #(241, ConversionFailure), #(242, CannotCreateCollection),
  #(243, IncompatibleWithUpgradedServer), #(245, BrokenPromise),
  #(246, SnapshotUnavailable), #(247, ProducerConsumerQueueBatchTooLarge),
  #(248, ProducerConsumerQueueEndClosed), #(249, StaleDbVersion),
  #(250, StaleChunkHistory), #(251, NoSuchTransaction),
  #(252, ReentrancyNotAllowed), #(253, FreeMonHttpInFlight),
  #(254, FreeMonHttpTemporaryFailure), #(255, FreeMonHttpPermanentFailure),
  #(256, TransactionCommitted), #(257, TransactionTooLarge),
  #(258, UnknownFeatureCompatibilityVersion), #(259, KeyedExecutorRetry),
  #(260, InvalidResumeToken), #(261, TooManyLogicalSessions),
  #(262, ExceededTimeLimit), #(263, OperationNotSupportedInTransaction),
  #(264, TooManyFilesOpen), #(265, OrphanedRangeCleanUpFailed),
  #(266, FailPointSetFailed), #(267, PreparedTransactionInProgress),
  #(268, CannotBackup), #(269, DataModifiedByRepair),
  #(270, RepairedReplicaSetNode), #(271, JSInterpreterFailureWithStack),
  #(272, MigrationConflict),
  #(273, ProducerConsumerQueueProducerQueueDepthExceeded),
  #(274, ProducerConsumerQueueConsumed), #(275, ExchangePassthrough),
  #(276, IndexBuildAborted), #(277, AlarmAlreadyFulfilled),
  #(278, UnsatisfiableCommitQuorum), #(279, ClientDisconnect),
  #(280, ChangeStreamFatalError), #(281, TransactionCoordinatorSteppingDown),
  #(282, TransactionCoordinatorReachedAbortDecision),
  #(283, WouldChangeOwningShard),
  #(284, ForTestingErrorExtraInfoWithExtraInfoInNamespace),
  #(285, IndexBuildAlreadyInProgress), #(286, ChangeStreamHistoryLost),
  #(287, TransactionCoordinatorDeadlineTaskCanceled), #(288, ChecksumMismatch),
  #(289, WaitForMajorityServiceEarlierOpTimeAvailable),
  #(290, TransactionExceededLifetimeLimitSeconds), #(291, NoQueryExecutionPlans),
  #(292, QueryExceededMemoryLimitNoDiskUseAllowed), #(293, InvalidSeedList),
  #(294, InvalidTopologyType), #(295, InvalidHeartBeatFrequency),
  #(296, TopologySetNameRequired), #(297, HierarchicalAcquisitionLevelViolation),
  #(298, InvalidServerType), #(299, OCSPCertificateStatusRevoked),
  #(300, RangeDeletionAbandonedBecauseCollectionWithUUIDDoesNotExist),
  #(301, DataCorruptionDetected), #(302, OCSPCertificateStatusUnknown),
  #(303, SplitHorizonChange), #(304, ShardInvalidatedForTargeting),
  #(306, ReadThroughCacheLookupCanceled),
  #(307, RangeDeletionAbandonedBecauseTaskDocumentDoesNotExist),
  #(308, CurrentConfigNotCommittedYet), #(309, ExhaustCommandFinished),
  #(310, PeriodicJobIsStopped), #(311, TransactionCoordinatorCanceled),
  #(312, OperationIsKilledAndDelisted), #(313, ResumableRangeDeleterDisabled),
  #(314, ObjectIsBusy), #(315, TooStaleToSyncFromSource),
  #(316, QueryTrialRunCompleted), #(317, ConnectionPoolExpired),
  #(318, ForTestingOptionalErrorExtraInfo), #(319, MovePrimaryInProgress),
  #(320, TenantMigrationConflict), #(321, TenantMigrationCommitted),
  #(322, APIVersionError), #(323, APIStrictError), #(324, APIDeprecationError),
  #(325, TenantMigrationAborted), #(326, OplogQueryMinTsMissing),
  #(327, NoSuchTenantMigration),
  #(328, TenantMigrationAccessBlockerShuttingDown),
  #(329, TenantMigrationInProgress), #(330, SkipCommandExecution),
  #(331, FailedToRunWithReplyBuilder), #(332, CannotDowngrade),
  #(333, ServiceExecutorInShutdown), #(334, MechanismUnavailable),
  #(335, TenantMigrationForgotten), #(9001, SocketException),
  #(10_003, CannotGrowDocumentInCappedNamespace), #(10_107, NotWritablePrimary),
  #(10_334, BSONObjectTooLarge), #(11_000, DuplicateKey),
  #(11_600, InterruptedAtShutdown), #(11_601, Interrupted),
  #(11_602, InterruptedDueToReplStateChange),
  #(12_586, BackgroundOperationInProgressForDatabase),
  #(12_587, BackgroundOperationInProgressForNamespace),
  #(13_113, MergeStageNoMatchingDocument), #(13_297, DatabaseDifferCase),
  #(13_388, StaleConfig), #(13_435, NotPrimaryNoSecondaryOk),
  #(13_436, NotPrimaryOrSecondary), #(14_031, OutOfDiskSpace),
  #(46_841, ClientMarkedKilled),
]
