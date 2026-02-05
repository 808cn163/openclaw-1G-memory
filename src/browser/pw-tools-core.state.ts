const disabled = () => {
  throw new Error("Browser automation is disabled in this build.");
};

export async function setOfflineViaPlaywright(): Promise<never> {
  return disabled();
}

export async function setExtraHTTPHeadersViaPlaywright(): Promise<never> {
  return disabled();
}

export async function setHttpCredentialsViaPlaywright(): Promise<never> {
  return disabled();
}

export async function setGeolocationViaPlaywright(): Promise<never> {
  return disabled();
}

export async function emulateMediaViaPlaywright(): Promise<never> {
  return disabled();
}

export async function setLocaleViaPlaywright(): Promise<never> {
  return disabled();
}

export async function setTimezoneViaPlaywright(): Promise<never> {
  return disabled();
}

export async function setDeviceViaPlaywright(): Promise<never> {
  return disabled();
}
