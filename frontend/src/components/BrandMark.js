import React from 'react';
import cartLogo from '../assets/logo/cart-logo.svg';
import { useSiteSettings } from '../context/SiteSettingsContext';

export default function BrandMark({ alt = 'Campus Mart cart logo', className = '', style }) {
  const { settings } = useSiteSettings();
  const [src, setSrc] = React.useState(settings.cartLogoUrl || cartLogo);

  React.useEffect(() => {
    setSrc(settings.cartLogoUrl || cartLogo);
  }, [settings.cartLogoUrl]);

  return (
    <img
      src={src}
      alt={alt}
      className={className}
      style={style}
      onError={() => setSrc(cartLogo)}
    />
  );
}
