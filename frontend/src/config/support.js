export const SUPPORT_EMAIL =
  process.env.REACT_APP_SUPPORT_EMAIL?.trim() || 'campusmart2@gmail.com';

export const SUPPORT_BUSINESS_EMAIL =
  process.env.REACT_APP_SUPPORT_BUSINESS_EMAIL?.trim() || SUPPORT_EMAIL;

export const SUPPORT_WHATSAPP_NUMBER =
  process.env.REACT_APP_SUPPORT_WHATSAPP_NUMBER?.replace(/\D/g, '') || '';

export const SUPPORT_WHATSAPP_LINK =
  SUPPORT_WHATSAPP_NUMBER ? `https://wa.me/${SUPPORT_WHATSAPP_NUMBER}` : '';

export const SUPPORT_RESPONSE_WINDOW = 'Usually within 24 business hours';
