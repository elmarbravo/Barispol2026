package com.barispol.workspace;

import android.os.Bundle;
import android.view.WindowManager;

import com.getcapacitor.BridgeActivity;

/*
 * Bloqueio de capturas de ecra (pedido do Elmar, 30-09-2026). FLAG_SECURE
 * impede prints e gravacoes de ecra na app, e esconde o conteudo na lista
 * de apps abertas. So vale na app Android: no navegador e no iPhone nao ha
 * forma de bloquear (ai fica a marca de agua do Workspace nos ecras com
 * dados sensiveis).
 */
public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE);
    }
}
