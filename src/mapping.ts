import { TransferSingle, TransferBatch } from "../generated/AscendantsDapp/AscendantsDapp";
import { Transfer } from "../generated/schema";
import { BigInt } from "@graphprotocol/graph-ts";

export function handleTransferSingle(event: TransferSingle): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let entity = new Transfer(id);
  entity.from = event.params.from;
  entity.to = event.params.to;
  entity.tokenId = event.params.id;
  entity.value = event.params.value;
  entity.timestamp = event.block.timestamp;
  entity.save();
}

export function handleTransferBatch(event: TransferBatch): void {
  // Lógica para TransferBatch
}
