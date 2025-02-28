import { TransferSingle, TransferBatch } from "../generated/AdrianGallery1155/AdrianGallery1155";
import { Transfer, Holder, TokenBalance } from "../generated/schema";
import { BigInt } from "@graphprotocol/graph-ts";

/**
 * handleTransferSingle
 * Se ejecuta cuando se emite un evento TransferSingle.
 */
export function handleTransferSingle(event: TransferSingle): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  let transfer = new Transfer(id);
  transfer.from = event.params.from;
  transfer.to = event.params.to;
  transfer.tokenId = event.params.id;
  transfer.value = event.params.value;
  transfer.timestamp = event.block.timestamp;
  transfer.save();

  // Aquí puedes agregar lógica adicional para actualizar balances o registrar propietarios.
}

/**
 * handleTransferBatch
 * Se ejecuta para eventos TransferBatch.
 */
export function handleTransferBatch(event: TransferBatch): void {
  for (let i = 0; i < event.params.ids.length; i++) {
    let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString() + "-" + i.toString();
    let transfer = new Transfer(id);
    transfer.from = event.params.from;
    transfer.to = event.params.to;
    transfer.tokenId = event.params.ids[i];
    transfer.value = event.params.values[i];
    transfer.timestamp = event.block.timestamp;
    transfer.save();

    // Aquí también puedes agregar lógica para actualizar balances o propietarios.
  }
}
