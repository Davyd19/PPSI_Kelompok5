import { createContext, useContext } from 'react';
export const ConfirmationContext = createContext(null);
export function useConfirm() { return useContext(ConfirmationContext); }
