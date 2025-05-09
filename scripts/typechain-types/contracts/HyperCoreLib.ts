/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BytesLike,
  FunctionFragment,
  Result,
  Interface,
  ContractRunner,
  ContractMethod,
  Listener,
} from "ethers";
import type {
  TypedContractEvent,
  TypedDeferredTopicFilter,
  TypedEventLog,
  TypedListener,
  TypedContractMethod,
} from "../common";

export interface HyperCoreLibInterface extends Interface {
  getFunction(
    nameOrSignature: "KNOWN_TOKEN_HYPE" | "KNOWN_TOKEN_USDC"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "KNOWN_TOKEN_HYPE",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "KNOWN_TOKEN_USDC",
    values?: undefined
  ): string;

  decodeFunctionResult(
    functionFragment: "KNOWN_TOKEN_HYPE",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "KNOWN_TOKEN_USDC",
    data: BytesLike
  ): Result;
}

export interface HyperCoreLib extends BaseContract {
  connect(runner?: ContractRunner | null): HyperCoreLib;
  waitForDeployment(): Promise<this>;

  interface: HyperCoreLibInterface;

  queryFilter<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;
  queryFilter<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;

  on<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  on<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  once<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  once<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  listeners<TCEvent extends TypedContractEvent>(
    event: TCEvent
  ): Promise<Array<TypedListener<TCEvent>>>;
  listeners(eventName?: string): Promise<Array<Listener>>;
  removeAllListeners<TCEvent extends TypedContractEvent>(
    event?: TCEvent
  ): Promise<this>;

  KNOWN_TOKEN_HYPE: TypedContractMethod<[], [bigint], "view">;

  KNOWN_TOKEN_USDC: TypedContractMethod<[], [bigint], "view">;

  getFunction<T extends ContractMethod = ContractMethod>(
    key: string | FunctionFragment
  ): T;

  getFunction(
    nameOrSignature: "KNOWN_TOKEN_HYPE"
  ): TypedContractMethod<[], [bigint], "view">;
  getFunction(
    nameOrSignature: "KNOWN_TOKEN_USDC"
  ): TypedContractMethod<[], [bigint], "view">;

  filters: {};
}
