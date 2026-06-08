ALTER TABLE money_documents
  DROP CONSTRAINT IF EXISTS money_documents_type_chk;

ALTER TABLE money_documents
  ADD CONSTRAINT money_documents_type_chk CHECK (
    document_type IN (
      'opening',
      'receipt',
      'payment',
      'transfer',
      'adjustment',
      'sale_payment',
      'sale_receivable',
      'purchase_payment',
      'purchase_payable',
      'salary',
      'tax'
    )
  );

ALTER TABLE money_documents
  DROP CONSTRAINT IF EXISTS money_documents_status_chk;

ALTER TABLE money_documents
  ADD CONSTRAINT money_documents_status_chk CHECK (
    status IN ('draft', 'partial', 'posted', 'cancelled')
  );
